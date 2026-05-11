<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Subscribe - Gesture App</title>
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0a0a0a; color: #e0e0e0; min-height: 100vh; }
        .container { max-width: 500px; margin: 0 auto; padding: 24px 16px; }
        .logo { text-align: center; margin-bottom: 24px; }
        .logo h1 { color: #00e676; font-size: 1.6rem; }
        .logo p { color: #888; font-size: 0.85rem; margin-top: 4px; }

        .plan-card {
            background: #1a1a1a;
            border: 2px solid #00e676;
            border-radius: 16px;
            padding: 24px;
            margin-bottom: 24px;
        }
        .plan-name { color: #fff; font-size: 1.4rem; font-weight: 700; }
        .plan-price { color: #00e676; font-size: 2rem; font-weight: 700; margin: 8px 0; }
        .plan-price span { color: #888; font-size: 0.9rem; font-weight: 400; }
        .plan-duration { color: #aaa; font-size: 0.9rem; margin-bottom: 16px; }

        .features { list-style: none; padding: 0; margin-bottom: 24px; }
        .features li { padding: 6px 0; color: #ccc; font-size: 0.9rem; display: flex; align-items: center; gap: 8px; }
        .features li::before { content: '✓'; color: #00e676; font-weight: bold; font-size: 1.1rem; }

        .user-info {
            background: #111;
            border: 1px solid #333;
            border-radius: 12px;
            padding: 16px;
            margin-bottom: 24px;
        }
        .user-info p { color: #aaa; font-size: 0.85rem; margin-bottom: 4px; }
        .user-info strong { color: #fff; }

        .pay-btn {
            display: block;
            width: 100%;
            padding: 16px;
            background: #00e676;
            color: #000;
            border: none;
            border-radius: 12px;
            font-size: 1.1rem;
            font-weight: 700;
            cursor: pointer;
            transition: all 0.2s;
        }
        .pay-btn:hover { background: #00c853; transform: translateY(-1px); }
        .pay-btn:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }

        .success-card {
            display: none;
            background: #0a2a0a;
            border: 2px solid #00e676;
            border-radius: 16px;
            padding: 32px;
            text-align: center;
        }
        .success-card h2 { color: #00e676; font-size: 1.5rem; margin-bottom: 12px; }
        .success-card p { color: #ccc; margin-bottom: 16px; }
        .success-card .emoji { font-size: 3rem; margin-bottom: 16px; }
        .back-btn {
            display: inline-block;
            padding: 12px 32px;
            background: transparent;
            color: #00e676;
            border: 1px solid #00e676;
            border-radius: 8px;
            font-size: 0.95rem;
            text-decoration: none;
            cursor: pointer;
        }

        .error-card {
            display: none;
            background: #2a0a0a;
            border: 2px solid #d32f2f;
            border-radius: 16px;
            padding: 24px;
            text-align: center;
            margin-bottom: 24px;
        }
        .error-card h3 { color: #ef5350; margin-bottom: 8px; }
        .error-card p { color: #ccc; }

        .secure-badge { text-align: center; color: #666; font-size: 0.8rem; margin-top: 16px; }
        .secure-badge span { color: #00e676; }

        .footer { text-align: center; margin-top: 32px; padding-top: 16px; border-top: 1px solid #222; }
        .footer a { color: #00e676; text-decoration: none; font-size: 0.85rem; }
    </style>
</head>
<body>
<div class="container">
    <div class="logo">
        <h1>⚡ Gesture App</h1>
        <p>Complete your subscription</p>
    </div>

    <div id="paymentSection">
        <div class="plan-card">
            <div class="plan-name">{{ $plan->name }}</div>
            <div class="plan-price">₹{{ number_format($plan->price, 0) }} <span>/ {{ $plan->duration_days }} days</span></div>
            @if($plan->features && is_array($plan->features))
            <ul class="features">
                @foreach($plan->features as $feature)
                <li>{{ ucfirst(str_replace('_', ' ', $feature)) }}</li>
                @endforeach
            </ul>
            @endif
        </div>

        <div class="user-info">
            <p>Subscribing as:</p>
            <strong>{{ $user->name }}</strong>
            <p style="margin-top: 4px;">{{ $user->email }}</p>
        </div>

        <div class="error-card" id="errorCard">
            <h3>❌ Payment Failed</h3>
            <p id="errorMsg">Something went wrong. Please try again.</p>
        </div>

        <button class="pay-btn" id="payBtn" onclick="startPayment()">
            💳 Pay ₹{{ number_format($plan->price, 0) }} Now
        </button>

        <div class="secure-badge">
            🔒 Secured by <span>Razorpay</span> • 256-bit encryption
        </div>
    </div>

    <div class="success-card" id="successCard">
        <div class="emoji">🎉</div>
        <h2>Payment Successful!</h2>
        <p>Your <strong>{{ $plan->name }}</strong> subscription is now active.<br>You can close this page and return to the Gesture App.</p>
        <p style="color: #888; font-size: 0.85rem;">Pull down to refresh in the app to see your updated plan.</p>
        <br>
        <a href="javascript:void(0)" class="back-btn" onclick="window.close()">Close This Page</a>
    </div>

    <div class="footer">
        <a href="/privacy">Privacy Policy</a> &nbsp;•&nbsp;
        <a href="mailto:support@gestureapp.com">Support</a>
    </div>
</div>

<script src="https://checkout.razorpay.com/v1/checkout.js"></script>
<script>
    const planId = {{ $plan->id }};
    const apiToken = "{{ $token }}";
    const razorpayKey = "{{ $razorpayKey }}";
    const userName = "{{ $user->name }}";
    const userEmail = "{{ $user->email }}";
    const userPhone = "{{ $user->phone ?? '' }}";
    const amount = {{ (int)($plan->price * 100) }};

    async function startPayment() {
        const btn = document.getElementById('payBtn');
        const errorCard = document.getElementById('errorCard');
        errorCard.style.display = 'none';
        btn.disabled = true;
        btn.textContent = 'Creating order...';

        try {
            // Step 1: Create order on backend
            const orderRes = await fetch('/api/subscription/create', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': 'Bearer ' + apiToken
                },
                body: JSON.stringify({ plan_id: planId })
            });

            if (!orderRes.ok) throw new Error('Failed to create order');
            const orderData = await orderRes.json();

            btn.textContent = 'Opening Razorpay...';

            // Step 2: Open Razorpay Checkout
            const options = {
                key: razorpayKey,
                amount: orderData.amount,
                currency: orderData.currency || 'INR',
                order_id: orderData.order_id,
                name: 'Gesture App',
                description: 'Subscribe to ' + '{{ $plan->name }}',
                prefill: {
                    name: userName,
                    email: userEmail,
                    contact: userPhone
                },
                handler: function(response) {
                    verifyPayment(response);
                },
                modal: {
                    ondismiss: function() {
                        btn.disabled = false;
                        btn.textContent = '💳 Pay ₹{{ number_format($plan->price, 0) }} Now';
                    }
                },
                theme: { color: '#00e676' }
            };

            const rzp = new Razorpay(options);
            rzp.on('payment.failed', function(response) {
                errorCard.style.display = 'block';
                document.getElementById('errorMsg').textContent = response.error.description || 'Payment failed';
                btn.disabled = false;
                btn.textContent = '💳 Pay ₹{{ number_format($plan->price, 0) }} Now';
            });
            rzp.open();

        } catch (err) {
            errorCard.style.display = 'block';
            document.getElementById('errorMsg').textContent = err.message || 'Could not initiate payment';
            btn.disabled = false;
            btn.textContent = '💳 Pay ₹{{ number_format($plan->price, 0) }} Now';
        }
    }

    async function verifyPayment(response) {
        const btn = document.getElementById('payBtn');
        btn.textContent = 'Verifying payment...';

        try {
            const verifyRes = await fetch('/api/razorpay/verify', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': 'Bearer ' + apiToken
                },
                body: JSON.stringify({
                    plan_id: planId,
                    razorpay_payment_id: response.razorpay_payment_id,
                    razorpay_order_id: response.razorpay_order_id,
                    razorpay_signature: response.razorpay_signature
                })
            });

            const data = await verifyRes.json();

            if (verifyRes.ok && data.status === 'success') {
                document.getElementById('paymentSection').style.display = 'none';
                document.getElementById('successCard').style.display = 'block';
            } else {
                throw new Error(data.message || 'Verification failed');
            }
        } catch (err) {
            const errorCard = document.getElementById('errorCard');
            errorCard.style.display = 'block';
            document.getElementById('errorMsg').textContent = 'Payment received but verification failed. Contact support.';
            btn.disabled = false;
            btn.textContent = '💳 Retry Payment';
        }
    }
</script>
</body>
</html>
