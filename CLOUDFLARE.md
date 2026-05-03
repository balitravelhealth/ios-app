# Cloudflare WAF — settings for `balihealth.me`

Native apps look like bots to Cloudflare. Apply these settings in order — the
zone-wide knobs first, then the surgical "Configuration Rules" / "WAF Custom
Rules" so the rest of the world stays protected.

> Everything below assumes the iOS client sends `User-Agent: BTH-IOS-7c3e9f …`
> per [BaliTravelHealth/Networking/AppUserAgent.swift](BaliTravelHealth/Networking/AppUserAgent.swift).
> If you change `AppUserAgent.appKey`, change the string in every rule below.

---

## 0. Quick checklist

- [ ] **SSL/TLS** mode: `Full (strict)`. **Min TLS Version**: `1.2`. **Always Use HTTPS**: ON.
- [ ] **Bots → Bot Fight Mode**: OFF (or use the skip rule in §4 if you want it on for the rest of the site)
- [ ] **Security → Settings → Browser Integrity Check**: OFF on `/internal/*` (skip rule in §3)
- [ ] **Security → Settings → Security Level**: `Medium`. Use the skip rule in §3 to drop `/internal/*` to "Essentially Off".
- [ ] **WAF → Managed rules**: keep ON, but add the skip rule in §3 for `/internal/*` requests with our UA.
- [ ] **WAF → Custom rules**: add the **block-everything-else** rule in §5.
- [ ] **Caching → Cache rules**: add the bypass rule in §6 so `/internal/*` is never cached.
- [ ] **Rate limiting**: add the rule in §7 for `/internal/credentials.php` and `/internal/passkey/*`.
- [ ] **AASA**: confirm `/.well-known/apple-app-site-association` is reachable
  without challenges (§8).
- [ ] **Page Rules / Speed → Auto Minify**: turn OFF for JSON. (Auto Minify
  doesn't touch `application/json`, but Rocket Loader / Email Obfuscation can —
  disable both for the zone or use the skip rule.)

---

## 1. SSL / TLS

| Setting | Value |
|---|---|
| Mode | **Full (strict)** — origin must serve a valid cert |
| Min TLS Version | **1.2** (1.3 if your origin supports it) |
| Always Use HTTPS | **ON** |
| Automatic HTTPS Rewrites | **ON** |
| HSTS | Already set by our `.htaccess`. You can additionally enable Cloudflare's HSTS with `max-age 31536000`, `includeSubDomains` ON, `preload` only after you're 100% sure. |

---

## 2. Disable the things that always misfire on native apps

In **Security → Settings**:

| Setting | Set to |
|---|---|
| Bot Fight Mode (free) | **OFF** *(or use §4)* |
| Super Bot Fight Mode (paid) | **OFF for "Definitely automated" requests on `/internal/*`** *(use §4)* |
| Browser Integrity Check | OFF zone-wide is acceptable for an API. Otherwise keep ON and skip via §3. |
| Challenge Passage | default |
| Security Level | **Medium** |

In **Speed → Optimization**:

| Setting | Set to |
|---|---|
| Rocket Loader | **OFF** (rewrites JS in HTML, useless for a JSON API) |
| Email Address Obfuscation | OFF |
| Auto Minify | OFF for the API zone (doesn't touch JSON anyway) |

---

## 3. Configuration Rule — drop the WAF for our app traffic

**Rules → Configuration Rules → Create rule**

```
Name: Allow BTH iOS app on /internal
Expression:
  (starts_with(http.request.uri.path, "/internal/")
   and starts_with(http.user_agent, "BTH-IOS-7c3e9f "))

Settings to override:
  Security Level         → Essentially Off
  Browser Integrity Check→ Off
  Email Obfuscation      → Off
  Rocket Loader          → Off
  Cache Level            → Bypass
```

This is the rule that stops Cloudflare from challenging the app while leaving
the WAF in place for all other traffic to your zone.

---

## 4. WAF Custom Rule — skip Managed Rules + Bot for our UA

**Security → WAF → Custom rules → Create rule**, action = **Skip**.

```
Name: Skip WAF for BTH iOS app
Expression:
  (starts_with(http.request.uri.path, "/internal/")
   and starts_with(http.user_agent, "BTH-IOS-7c3e9f "))

Action: Skip
Skip:
  ☑ All Managed Rules
  ☑ Bot Fight Mode (and Super Bot Fight Mode if on the paid plan)
  ☑ Rate Limiting Rules   ← see §7 below; keep this OFF if you want the
                            limits to apply to the app too (recommended)
Order: place this rule FIRST.
```

> **Why Skip and not Allow?** *Allow* in CF terms also bypasses Custom Rules
> created later (e.g. the deny-all in §5). *Skip* lets later rules still run
> but turns off the noisy managed checks that misfire on native apps.

---

## 5. WAF Custom Rule — block everyone else from `/internal/*`

This is the second layer of defence after the User-Agent gate in
[backend/lib/http.php](backend/lib/http.php). Cloudflare drops the request
before it ever hits PHP.

```
Name: Block /internal/* without app UA
Expression:
  (starts_with(http.request.uri.path, "/internal/")
   and not starts_with(http.user_agent, "BTH-IOS-7c3e9f "))

Action: Block
Order: place AFTER the Skip rule from §4 so app traffic is allowed first.
```

If your back-office tooling (curl, Postman) needs to hit `/internal/*` for
testing, either:

- pass `-A "BTH-IOS-7c3e9f curl/test"`, or
- add an exception:
  ```
  or (ip.src in {1.2.3.4 5.6.7.8})
  ```

---

## 6. Cache rules — never cache the API

**Caching → Cache Rules → Create rule**

```
Name: Bypass cache on /internal
Expression:
  starts_with(http.request.uri.path, "/internal/")

Cache eligibility: Bypass cache
Origin Cache Control: Respect (off)
```

You can add a *separate* cache rule that DOES cache `/internal/nurses.php` for
e.g. 60 seconds at the edge — but only if you're sure that endpoint is safe to
cache. The default safe choice is "bypass everything under `/internal`".

---

## 7. Rate limiting — protect login + passkey

**Security → WAF → Rate limiting rules**

```
Name: Limit /internal/credentials.php
Expression: http.request.uri.path eq "/internal/credentials.php"
Action: Managed Challenge after threshold
Threshold: 10 requests per IP per minute
Mitigation period: 1 minute
```

```
Name: Limit /internal/passkey/*
Expression: starts_with(http.request.uri.path, "/internal/passkey/")
Action: Managed Challenge
Threshold: 20 requests per IP per minute
```

```
Name: Burst limit /internal/*
Expression: starts_with(http.request.uri.path, "/internal/")
Action: Block
Threshold: 600 requests per IP per minute     ← absurdly high; only stops attacks
```

> Make sure §4's Skip rule does **not** include "Rate Limiting Rules", so
> these limits still apply to the app. A misbehaving build of the iOS app
> shouldn't be able to hammer the server.

---

## 8. AASA passthrough

`/.well-known/apple-app-site-association` is fetched by Apple's `swcd` daemon
on every device that opens your app. The fetch comes from random IPs with a
generic User-Agent — Cloudflare's defaults can challenge them.

**Configuration Rules → Create rule**

```
Name: AASA passthrough
Expression:
  http.request.uri.path eq "/.well-known/apple-app-site-association"

Settings to override:
  Security Level         → Essentially Off
  Browser Integrity Check→ Off
  Cache Level            → Standard
  Edge Cache TTL         → 4 hours
```

Verify after deploy:

```bash
curl -I https://balihealth.me/.well-known/apple-app-site-association
# expect:
#   HTTP/2 200
#   content-type: application/json
#   server: cloudflare
```

If you see a `cf-mitigated: challenge` header, the rule isn't catching the
request — review §8's expression.

---

## 9. CORS

Native iOS apps **don't trigger CORS** (no Origin header on `URLSession`
requests). Don't waste rules on `Access-Control-*` headers.

If you ever add a web client, the lightest-touch fix is at the origin level
(add `Header set Access-Control-Allow-Origin` in `.htaccess`) rather than CF
Transform Rules, which can interfere with caching.

---

## 10. Verifying the whole stack

Once everything is in place, all four of these should behave correctly from a
fresh terminal (you may need to `--resolve` if Cloudflare returns a different
IP than your origin):

```bash
# 1. Public list — should return 200 with the seeded nurses.
curl -i -A "BTH-IOS-7c3e9f curl/test" \
  https://balihealth.me/internal/nurses.php

# 2. Wrong UA — Cloudflare blocks at the edge (HTTP 403).
curl -i https://balihealth.me/internal/nurses.php

# 3. Auth required — origin says 401 (request reaches PHP).
curl -i -A "BTH-IOS-7c3e9f curl/test" \
  https://balihealth.me/internal/appointments-active.php

# 4. AASA — 200 + application/json, no challenge.
curl -i https://balihealth.me/.well-known/apple-app-site-association
```

If #1 returns `cf-mitigated: challenge` or `403` from `cloudflare`, the Skip
rule (§4) isn't running — re-check rule order.
If #2 returns from the origin (`server: nginx`/`apache`) instead of Cloudflare,
your block rule (§5) didn't match.
If #4 returns a Cloudflare challenge page, the AASA passthrough (§8) didn't
match — Apple will silently fail to register the relying party and Passkeys
will not work.

---

## 11. Rule-order summary (top to bottom)

```
WAF → Custom rules:
  1. Skip   →  Allow BTH iOS app on /internal           (§4)
  2. Block  →  Block /internal/* without app UA         (§5)

Rules → Configuration Rules:
  1. Allow BTH iOS app on /internal                      (§3)
  2. AASA passthrough                                    (§8)

Caching → Cache Rules:
  1. Bypass cache on /internal                           (§6)

Security → Rate limiting:
  1. Limit /internal/credentials.php                     (§7)
  2. Limit /internal/passkey/*                           (§7)
  3. Burst limit /internal/*                             (§7)
```

That order matters — the **Skip** rule has to fire before the **Block** rule,
otherwise legitimate app traffic is blocked. The Configuration Rule overrides
are evaluated independently of WAF rules, so their relative order is purely
cosmetic.
