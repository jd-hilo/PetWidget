# Loops + Supabase: OTP sign-in setup (Petmoji)

End-to-end guide so sign-up and sign-in send a **6-digit numeric code** (not a magic link) and the Petmoji app can verify it.

**How it works:** The app calls `signInWithOTP` → Supabase Auth → Loops SMTP → Loops sends your **published** transactional email with `{{ .Token }}` → user types the code in the app → `verifyOTP`.

---

## Prerequisites

- Supabase project (petmoji)
- Loops account
- A domain you can edit DNS for (required to **publish** in Loops)
- Petmoji `SignUpOTPConfig.length` matches Supabase **OTP length** (currently **6** in [`Petmoji/SignUp/SignUpDraft.swift`](Petmoji/SignUp/SignUpDraft.swift))

---

## Part 1 — Verify sending domain in Loops

You usually **cannot publish** transactional emails until a domain is verified.

1. Open [Loops → Settings → Domain](https://app.loops.so/settings?page=domain).
2. Add your sending domain (subdomain like `mail.yourdomain.com` is fine).
3. Copy the DNS records Loops provides (SPF, DKIM, etc.) into your DNS provider.
4. Wait until Loops shows the domain as **Verified** (minutes to 48 hours).

Sender name/email in Loops templates come from this domain setup.

---

## Part 2 — Connect Loops SMTP to Supabase

**Option A — One-click (recommended)**

1. [Loops → Settings → Supabase](https://app.loops.so/settings?page=supabase) → **Connect Supabase**.
2. Authorize, pick your Supabase project, choose a Loops API key → **Set up SMTP**.

**Option B — Manual**

In Supabase → **Authentication → Emails → SMTP**:

| Field | Value |
|--------|--------|
| Enable custom SMTP | On |
| Host | `smtp.loops.so` |
| Port | `587` |
| Username | `loops` |
| Password | Loops API key from [Settings → API](https://app.loops.so/settings?page=api) |
| Sender name | `Petmoji` (optional; Loops template may override) |
| Minimum interval per user | `60` seconds |

Save changes.

Then in Supabase → **Authentication → Rate Limits**, set **Emails sent per hour** (e.g. 60–100 for dev) and **OTP** limits as needed.

---

## Part 3 — Supabase Auth: OTP-only (no magic link in app)

1. **Authentication → Providers → Email**
   - Email enabled
   - **OTP length: 6** — must match `SignUpOTPConfig.length` in the app
   - **Confirm email** can stay **off** (user verifies via code in app)

2. Do **not** set a redirect URL in the app (OTP is entered in-app, not via link).

---

## Part 4 — Create “Magic Link” transactional email in Loops

Supabase still uses the template named **Magic Link** for OTP sends. The email must show the code, not a login URL.

1. [Loops → Transactional](https://app.loops.so/transactional) → **New**.
2. Name it e.g. `Petmoji OTP` (internal name only).
3. Design a simple email:
   - Subject: `Your Petmoji sign-in code`
   - Body: short text + **dynamic field for the code**
4. Add a **data variable** for the OTP:
   - In the editor, type `{` or use the dynamic content menu
   - Add a variable — e.g. **`token`** (remember exact spelling/casing)
   - Place it large in the body: “Enter this code: **{token}**”
5. Set **From** / sender (uses your verified domain).
6. Open **Review** in the left sidebar:
   - Fix every warning (subject, from, content, domain)
7. Click **Publish** (requires verified domain from Part 1).

Use [`Supabase/email-templates/magic-link-otp.html`](Supabase/email-templates/magic-link-otp.html) as a **design reference** only — paste into the Loops editor, not Supabase.

---

## Part 5 — Create “Confirm signup” in Loops (required)

If the user isn’t “confirmed” yet, Supabase may send **Confirm signup** instead of Magic Link.

1. Transactional → **New** → e.g. `Petmoji Confirm signup`.
2. Same idea: include **`token`** mapped to the code.
3. **Publish** this email too.

---

## Part 6 — Copy JSON payload into Supabase (critical)

Loops SMTP does **not** use HTML in Supabase. Each auth template body must be **JSON only**.

### Magic Link template in Supabase

1. In Loops, open your **published** OTP email → **Review** → copy the **API payload** (clipboard icon).
2. Supabase → **Authentication → Emails** → **Magic Link**.
3. **Delete all HTML** in the message body.
4. Paste JSON. Example shape (use **your** `transactionalId` and **your** variable names from Loops):

```json
{
  "transactionalId": "YOUR_TRANSACTIONAL_ID",
  "email": "{{ .Email }}",
  "dataVariables": {
    "token": "{{ .Token }}"
  }
}
```

- `transactionalId` = from Loops Review
- Keys inside `dataVariables` must **exactly match** the data variable names in the Loops editor (`token` vs `Token` vs `var0` matters)
- `{{ .Token }}` is the OTP from Supabase (length = 6 digits)
- **Every value must be a quoted string** — `"token": "{{ .Token }}"` not `"token": {{.Token}}`

### Troubleshooting: email shows `var0` or literal text instead of the code

This means the Loops **data variable name** in your email design does not match the key in `dataVariables`.

1. In Loops, click the large code area in your template — if it says `var0`, that is the variable name Loops assigned (not static text).
2. Either rename it to `token` in the Loops editor (recommended), or use whatever name Loops shows in **Review → API payload**.
3. Do **not** type the word `Token` as plain text — use **Insert data variable** (type `{` in the editor) so Loops knows to substitute it.
4. In Supabase, the JSON must look like this (note quotes and spaces):

```json
{
  "transactionalId": "cmpx1cdu801mg0j4rl7ncr07q",
  "email": "{{ .Email }}",
  "dataVariables": {
    "token": "{{ .Token }}"
  }
}
```

If you keep Loops' default name, match it exactly:

```json
"dataVariables": {
  "var0": "{{ .Token }}"
}
```

5. Re-publish the Loops email after changing variables, then update the Supabase template body.

5. Save the template.

### Confirm signup template in Supabase

1. Copy the **Confirm signup** payload from its published Loops email.
2. Supabase → **Emails** → **Confirm signup** → paste JSON (not HTML).
3. Any variable in Confirm signup must also exist in Magic Link if Supabase might send either.

**Wrong (causes `450 valid JSON payload`):**

```html
<p>Your code: {{ .Token }}</p>
```

**Right:** only the JSON block above.

---

## Part 7 — Test before using the app

### A. Test from Supabase

1. **Authentication → Users** → **Add user** → **Create new user** (enter an email you control).
2. **Click the new user row** in the table — a side panel opens (the button is not on the empty list page).
3. In the panel, click **Send magic link** (or **Send confirmation email** if the user is unconfirmed).
4. Check [Loops → Transactional](https://app.loops.so/transactional) → your email → **Metrics / sends** — should show delivered.
5. Inbox should show a **6-digit code** (not “click to log in”).

### B. Test from Petmoji app

1. Sign out if needed (Settings → sign out).
2. **Sign-up:** name → email → phone → **send code** → enter 6 digits → **verify** → onboarding.
3. **Sign-in:** email → **send code** → enter 6 digits → **sign in** → home/onboarding.

### C. If it fails

| Log / error | Fix |
|-------------|-----|
| `450 … valid JSON payload` | Supabase template still HTML; use JSON from Loops Review |
| `error sending magic link email` | Usually **Confirm signup** template missing or still HTML — configure both Magic Link **and** Confirm signup with Loops JSON; check [Logs → Auth](https://supabase.com/dashboard/project/_/logs/auth-logs) |
| Rate limit | Wait 60s; raise Rate Limits |
| Code wrong in app | `SignUpOTPConfig.length` ≠ Supabase OTP length |
| Sign-in: no account | Expected when email unknown (`shouldCreateUser: false`) |
| Email shows `var0` or `Token` literally | Loops variable name ≠ `dataVariables` key; use `{token}` dynamic field, not static text; quote values in JSON |

---

## Part 8 — App implementation

| Component | Behavior |
|-----------|----------|
| `SupabaseService.sendEmailOTP` | `signInWithOTP(email:shouldCreateUser:)` — sign-up uses `true`, sign-in uses `false` |
| `SupabaseService.verifyEmailOTP` | `verifyOTP(email:token:type: .email)` — establishes session |
| `SignUpCoordinator` | Sends OTP after phone step; verifies on OTP step; then `upsertProfile` |
| `SignInView` | Email step → send code; OTP step → verify → `restoreAuthenticatedSession` |
| `EmailOTPFieldView` | Shared 6-box input with resend (60s cooldown) |
| `SignUpOTPConfig.length` | **6** — must match Supabase dashboard |

No redirect URL is passed — verification is in-app only.

---

## Quick reference

| Layer | OTP code variable |
|--------|-------------------|
| Supabase Auth | Generates `{{ .Token }}` |
| Supabase Magic Link template body | `"token": "{{ .Token }}"` in JSON |
| Loops email design | Shows `{token}` data variable |
| Petmoji app | User types code; `verifyOTP` |

Official Loops doc: [Supabase SMTP](https://loops.so/docs/smtp/supabase)
