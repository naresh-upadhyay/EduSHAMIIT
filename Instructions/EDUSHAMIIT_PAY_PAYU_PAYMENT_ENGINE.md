# EduSHAMIIT Pay — Centralized Payment Engine & PayU Integration Architecture

## 1. Executive Summary & Architectural Overview

EduSHAMIIT Pay is the unified, institutional Central Payment Engine for the EduSHAMIIT School ERP ecosystem. It serves as the single source of truth for all payment activities across both primary ecosystems:
1. **Ecosystem 1 (Corporate SaaS)**: School subscription license billings, plan renewals, and platform tier invoicing.
2. **Ecosystem 2 (Institutional Fees)**: Student tuition, transport, lab, admission, and miscellaneous fee collections with dynamic QR, UPI Intent, Net Banking, and Card processing.

All duplicate "Payment Gateways" modules and navigation entries have been eradicated. Payment gateway configuration, health monitoring, transaction ledgers, webhooks, reconciliation, and audit streams now operate under **EduSHAMIIT Pay**.

```
                         EDUSHAMIIT ERP
                               │
                         EDUSHAMIIT PAY
                    (Central Payment Engine)
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
  Payment Engine         Configuration          Webhook & Audit
  (Lifecycle & State)   (Providers & Keys)      (Reconciliation)
        │                      │                      │
   ┌────┴────┐                 │                      │
  PayU     Future          (PayU Test/Live)           │
Adapter   Adapters                                    │
   │                                                  │
   └───────────────────────────┬──────────────────────┘
                               │
                      Authoritative Records
                               │
            ┌──────────────────┼──────────────────┐
            │                  │                  │
        School Fees      Subscriptions         Invoices
            │                  │                  │
            └──────────────────┼──────────────────┘
                               │
                            Receipts
                               │
                         Reconciliation
```

---

## 2. Navigation & Sidebar Information Architecture

The sidebar contains strictly:
```
Finance Management
   ├── Overview
   ├── Revenue
   ├── Fee Collection
   ├── Expenses
   └── Payroll

EduSHAMIIT Pay
```

### EduSHAMIIT Pay Sub-Navigation Tabs:
Within `EduSHAMIIT Pay` (`/admin/payments` and `/payment-engine/payments`), administrators have access to 7 consolidated views:
- **Tab 0 — Overview**: High-level institutional collection dashboards, real-time KPI metrics, and settlement banking overview.
- **Tab 1 — Payments**: Centralized payment transactions workspace, real KPI cards, 2-row collapsible filter panel, pagination, CSV exports, inline detail drawer, and retry/reconciliation actions.
- **Tab 2 — Gateways / Configuration**: Provider management (PayU, Cashfree, SBI ePay, ICICI), secure credential configuration, live connection testing, and default gateway selection.
- **Tab 3 — Payment Requests / Transactions**: Student fee transaction records with status filtering and receipts.
- **Tab 4 — Webhooks**: Real-time incoming server-to-server webhook stream, HMAC/hash validation status, and safe payload inspection.
- **Tab 5 — Reconciliation**: Automated batch settlement reconciliation, discrepancy detection, and manual auditor resolution with UTR attachment.
- **Tab 6 — Settings / Merchant**: Institutional settlement bank accounts, UPI VPA setup, and acquirer credentials.

Legacy URLs (`/admin/payment-gateways`, `/payment-gateways`, `/academic/payment-gateways`, `/admin/payment-engine/gateways`) cleanly redirect directly into `EduSHAMIIT Pay (Tab 2: Gateways)` without dead links or 404s.

---

## 3. Gateway Abstraction Layer

The engine uses a gateway-independent provider layer. Any future gateway (SBI, ICICI, HDFC, Razorpay, Cashfree) plugs into `PaymentProvider`:

```python
class PaymentProvider(ABC):
    @abstractmethod
    async def create_order(self, order_id: str, amount: float, currency: str, customer_info: dict, ...) -> dict:
        pass

    @abstractmethod
    async def verify_payment(self, gateway_payment_id: str, ...) -> dict:
        pass

    @abstractmethod
    async def process_webhook(self, payload: dict, headers: dict) -> dict:
        pass

    @abstractmethod
    async def refund(self, gateway_payment_id: str, amount: float, reason: str) -> dict:
        pass

    @abstractmethod
    async def check_health(self) -> dict:
        pass
```

### PayU Provider Implementation (`PayUProvider`)
Located in `app/services/payment/payu_provider.py`:
- **Hosted Checkout**: Standard server-generated payment request redirecting customer to PayU's hosted payment page (`https://secure.payu.in/_payment` in production, `https://test.payu.in/_payment` in sandbox/test).
- **Request Hashing (SHA-512)**:
  `sha512(key|txnid|amount|productinfo|firstname|email|udf1|udf2|udf3|udf4|udf5||||||salt)`
  Generated exclusively server-side. Salt is strictly excluded from outgoing form parameters and browser URLs.
- **Reverse Hash Verification**:
  Validates incoming response hash against PayU's documented reverse sequence:
  `sha512(salt|status||||||udf5|udf4|udf3|udf2|udf1|email|firstname|productinfo|amount|txnid|key)`
  If `additionalCharges` are present:
  `sha512(additionalCharges|salt|status|...|key)`
- **Server Verification API**:
  Executes `verify_payment` command to PayU postservice endpoint (`https://info.payu.in/merchant/postservice.php?form=2` in production, `https://test.payu.in/merchant/postservice?form=2` in test) with command hash:
  `sha512(key|command|var1|salt)`
- **Refund API**:
  Executes `cancel_refund_transaction` with command hash:
  `sha512(key|cancel_refund_transaction|payuid|salt)`

---

## 4. Multi-Tenant Security & Zero Plaintext Credential Exposure

1. **Strict Credential Masking**:
   - `merchant_salt` and `api_secret` are never transmitted to the browser or frontend.
   - Gateway queries return masked strings (`••••••••` + last 4 characters).
   - In local development, credentials synchronize safely through authenticated backend endpoints directly to server configuration/environment.
2. **Authoritative Amount Validation**:
   - The payable amount is derived strictly from the backend invoice / subscription business record.
   - If the incoming client or gateway amount differs (`PAYMENT_AMOUNT_MISMATCH`), the transaction is immediately rejected and flagged.
3. **Tenant Scoping**:
   - All payment orders, attempts, webhooks, refunds, and receipts enforce `school_id` tenant isolation. Cross-school access is blocked with 403/404.
4. **Idempotency**:
   - Inbound webhook deliveries enforce unique idempotency constraints on `(gateway, gateway_event_id)` and `(gateway, gateway_transaction_id)`. Duplicate webhook requests are acknowledged without duplicate ledger increments or double receipts.

---

## 5. End-to-End Payment Flow

1. **Order Creation**:
   - Parent / School clicks `Pay Now`.
   - Frontend calls `POST /api/v1/payments/create` or `POST /api/v1/edushamiit-pay/payments`.
   - Backend validates tenant, invoice balance, creates internal `payment_orders` record (status: `PENDING`), generates unique transaction ID, creates `payment_attempts` Attempt #1, builds PayU SHA-512 hash, and returns hosted checkout payload.
2. **Hosted Checkout**:
   - Browser posts form to PayU Hosted Checkout (`https://test.payu.in/_payment` or `https://secure.payu.in/_payment`).
   - Customer completes payment via UPI, Card, Net Banking, or Wallet on PayU.
3. **Callback & Webhook**:
   - PayU posts back to server callback `/api/v1/payments/payu/callback/success` or `/failure`.
   - PayU sends server-to-server webhook to `/api/v1/payments/payu/webhook`.
   - Backend validates reverse hash signature, compares amount, marks order `SUCCESS`, and updates ERP business records (fee invoices, subscriptions).
4. **Receipt Generation**:
   - Official verified receipt generated with immutable receipt number `RCP-EDUPAY-...`.
   - Accessible via `GET /api/v1/edushamiit-pay/payments/{id}/receipt`.

---

## 6. How to Configure PayU (Administrator Guide)

1. Log in as an authorized School Admin or Super Admin.
2. In the sidebar, select **EduSHAMIIT Pay**.
3. Select **Gateways / Configuration** (Tab 2).
4. Locate the **PayU** card and click **Configure**.
5. Select the Environment (**Test / Sandbox** or **Production / Live**).
6. Enter the **Merchant Key** and **Merchant Salt**.
7. Click **Test Connection** — the backend executes a real authentication verification test with PayU.
8. Click **Save & Connect**.
9. To make PayU the primary payment processor for fees and subscriptions, click **Set as Default Gateway**.
