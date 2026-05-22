# Loops + Supabase: OTP sign-in setup (Petmoji)

> **Obsolete:** Petmoji now uses email + password auth (see [`README.md`](README.md) §2b). Keep this doc only if you re-enable OTP verification later.

End-to-end guide so sign-up sends a **numeric code** (not a magic link) and the Petmoji app can verify it.

**How it works:** The app calls `signInWithOTP` → Supabase Auth → Loops SMTP → Loops sends your **published** transactional email with `{{ .Token }}` → user types the code in the app → `verifyOTP`.

---

## Prerequisites

- Supabase project (petmoji)
- Loops account
- A domain you can edit DNS for (required to **publish** in Loops)
- Petmoji `SignUpOTPConfig.length` matches Supabase **OTP length** (currently **8** in `Petmoji/SignUp/SignUpDraft.swift`)

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

**Option B — Manual (matches your current screen)**

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
   - Note **OTP length** (6–10) — must match `SignUpOTPConfig.length` in the app
   - **Confirm email** can stay **off** (user verifies via code in app)

2. Do **not** set a redirect URL in the app (already omitted in code).

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

---

## Part 5 — Create “Confirm signup” in Loops (required)

If the user isn’t “confirmed” yet, Supabase may send **Confirm signup** instead of Magic Link.

1. Transactional → **New** → e.g. `Petmoji Confirm signup`.
2. Same idea: include **`token`** (or same variable name) mapped to the code if you use OTP there, or `confirmationUrl` if you use a link for confirm-only flows.
3. For OTP-only sign-up, simplest approach: same code variable `{{ .Token }}` in the Loops design and JSON payload.
4. **Publish** this email too.

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
  "transactionalId": "cmpg1m25708lu0jwvkseer1i4",
  "email": "{{ .Email }}",
  "dataVariables": {
    "token": "{{ .Token }}"
  }
}
```

- `transactionalId` = from Loops Review (yours was `cmpg1m25708lu0jwvkseer1i4`)
- Keys inside `dataVariables` must **exactly match** the data variable names in the Loops editor (`token` vs `Token` matters)
- `{{ .Token }}` is the OTP from Supabase (length = your OTP setting, e.g. 8 digits)

5. Save the template.

### Confirm signup template in Supabase

1. Copy the **Confirm signup** payload from its published Loops email.
2. Supabase → **Emails** → **Confirm signup** → paste JSON (not HTML).
3. Any variable in Confirm signup must also exist in Magic Link if Supabase might send either (Loops/Supabase requirement).

**Wrong (causes `450 valid JSON payload`):**

```html
<p>Your code: {{ .Token }}</p>
```

**Right:** only the JSON block above.

---

## Part 7 — Test before using the app

### A. Test from Supabase

1. **Authentication → Users** → **Add user** (email you control) or pick existing user.
2. **Send magic link** (sends via Loops using Magic Link JSON).
3. Check [Loops → Transactional](https://app.loops.so/transactional) → your email → **Metrics / sends** — should show delivered.
4. Inbox should show the **numeric code** (not “click to log in”).

### B. Test from Petmoji app

1. Sign out if needed (Settings → sign out).
2. Sign-up: name → email → phone → **continue** (sends OTP).
3. Enter full code (8 digits if that’s your Supabase OTP length).
4. **verify →** should complete and continue to onboarding.

### C. If it fails

| Log / error | Fix |
|-------------|-----|
| `450 … valid JSON payload` | Supabase template still HTML; use JSON from Loops Review |
| `error sending magic link email` | Loops publish/domain/SMTP; check [Logs → Auth](https://supabase.com/dashboard/project/_/logs/auth-logs) |
| Rate limit | Wait 60s; raise Rate Limits |
| Code wrong in app | `SignUpOTPConfig.length` ≠ Supabase OTP length |

---

## Part 8 — App checklist (already implemented)

- Sends OTP: `SupabaseService.sendEmailOTP` on phone step
- Verifies: `verifyEmailOTP` with `type: .email`
- UI: 8 boxes if `SignUpOTPConfig.length = 8`
- No `redirectTo` (OTP in-app, not link)

No app changes needed once Loops + Supabase templates are correct.

---

## Quick reference

| Layer | OTP code variable |
|--------|-------------------|
| Supabase Auth | Generates `{{ .Token }}` |
| Supabase Magic Link template body | `"token": "{{ .Token }}"` in JSON |
| Loops email design | Shows `{token}` data variable |
| Petmoji app | User types code; `verifyOTP` |

Official Loops doc: [Supabase SMTP](https://loops.so/docs/smtp/supabase)
