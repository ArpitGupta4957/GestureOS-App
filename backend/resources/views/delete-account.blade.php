<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Delete Account - MyDial</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0a0a0a; color: #e0e0e0; line-height: 1.7; }
        .container { max-width: 600px; margin: 0 auto; padding: 40px 24px; }
        h1 { font-size: 2rem; color: #00e676; margin-bottom: 8px; }
        .subtitle { color: #888; font-size: 0.95rem; margin-bottom: 32px; }
        h2 { font-size: 1.2rem; color: #fff; margin: 24px 0 12px; }
        p, li { color: #ccc; font-size: 0.95rem; margin-bottom: 12px; }
        ul { padding-left: 24px; margin-bottom: 16px; }
        li { margin-bottom: 6px; }
        .warning { background: #1a1a00; border: 1px solid #665500; border-radius: 8px; padding: 16px; margin: 20px 0; }
        .warning strong { color: #ffcc00; }
        .form-group { margin-bottom: 20px; }
        label { display: block; color: #aaa; font-size: 0.9rem; margin-bottom: 6px; font-weight: 500; }
        input, textarea { width: 100%; padding: 12px 16px; background: #1a1a1a; border: 1px solid #333; border-radius: 8px; color: #fff; font-size: 0.95rem; font-family: inherit; }
        input:focus, textarea:focus { outline: none; border-color: #00e676; }
        textarea { resize: vertical; min-height: 80px; }
        .btn { display: inline-block; padding: 14px 32px; background: #d32f2f; color: #fff; border: none; border-radius: 8px; font-size: 1rem; font-weight: 600; cursor: pointer; width: 100%; }
        .btn:hover { background: #b71c1c; }
        .btn:disabled { opacity: 0.5; cursor: not-allowed; }
        .success { display: none; background: #0a2a0a; border: 1px solid #1b5e20; border-radius: 8px; padding: 24px; text-align: center; margin-top: 20px; }
        .success h3 { color: #00e676; margin-bottom: 8px; }
        .error-msg { color: #ef5350; font-size: 0.85rem; margin-top: 4px; display: none; }
        a { color: #00e676; text-decoration: none; }
        .footer { margin-top: 48px; padding-top: 24px; border-top: 1px solid #222; color: #666; font-size: 0.85rem; }
    </style>
</head>
<body>
<div class="container">
    <h1>Delete Your Account</h1>
    <p class="subtitle">Request permanent deletion of your MyDial app account and data.</p>

    <h2>What happens when you delete your account?</h2>
    <ul>
        <li>Your account and login credentials will be permanently deleted.</li>
        <li>All saved gestures, shortcuts, and configurations will be removed.</li>
        <li>Contact aliases and bulk dialer data will be erased.</li>
        <li>Subscription data will be cancelled.</li>
        <li>This action <strong>cannot be undone</strong>.</li>
    </ul>

    <div class="warning">
        <strong>⚠️ Important:</strong> Account deletion is permanent and will be processed within 30 days. You can also delete your account directly from the app: <strong>Settings → Delete Account</strong>.
    </div>

    <h2>Request Account Deletion</h2>
    <p>Enter the email address associated with your account to submit a deletion request.</p>

    <form id="deleteForm" onsubmit="submitRequest(event)">
        @csrf
        <div class="form-group">
            <label for="email">Email Address *</label>
            <input type="email" id="email" name="email" required placeholder="your@email.com">
            <p class="error-msg" id="emailError"></p>
        </div>
        <div class="form-group">
            <label for="reason">Reason for deletion (optional)</label>
            <textarea id="reason" name="reason" placeholder="Let us know why you're leaving..."></textarea>
        </div>
        <button type="submit" class="btn" id="submitBtn">🗑️ Request Account Deletion</button>
    </form>

    <div class="success" id="successMsg">
        <h3>✅ Deletion Request Submitted</h3>
        <p>Your account deletion request has been received. Your account and all associated data will be permanently deleted within <strong>30 days</strong>. You will receive a confirmation email.</p>
    </div>

    <div class="footer">
        <p>Questions? Contact us at <a href="mailto:support@servermine.com">support@servermine.com</a></p>
        <p style="margin-top: 8px;"><a href="/privacy">Privacy Policy</a></p>
        <p style="margin-top: 8px;">&copy; {{ date('Y') }} MyDial by Bluvin Solutions. All rights reserved.</p>
    </div>
</div>

<script>
async function submitRequest(e) {
    e.preventDefault();
    const email = document.getElementById('email').value.trim();
    const reason = document.getElementById('reason').value.trim();
    const btn = document.getElementById('submitBtn');
    const errorEl = document.getElementById('emailError');

    errorEl.style.display = 'none';
    btn.disabled = true;
    btn.textContent = 'Submitting...';

    try {
        const res = await fetch('/api/account/request-deletion', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
            body: JSON.stringify({ email, reason })
        });
        const data = await res.json();

        if (res.ok) {
            document.getElementById('deleteForm').style.display = 'none';
            document.getElementById('successMsg').style.display = 'block';
        } else {
            errorEl.textContent = data.message || 'Something went wrong. Please try again.';
            errorEl.style.display = 'block';
            btn.disabled = false;
            btn.textContent = '🗑️ Request Account Deletion';
        }
    } catch (err) {
        errorEl.textContent = 'Network error. Please try again later.';
        errorEl.style.display = 'block';
        btn.disabled = false;
        btn.textContent = '🗑️ Request Account Deletion';
    }
}
</script>
</body>
</html>
