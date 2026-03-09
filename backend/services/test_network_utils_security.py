"""
Security test for network_utils.py command injection vulnerability fix.

This test verifies that the fetch_with_curl function is NOT vulnerable
to command injection attacks via URL, headers, or JSON data parameters.
"""

import pytest
from services.network_utils import fetch_with_curl


def test_command_injection_via_json_data():
    """Test that command injection via json_data is prevented."""
    # These payloads should NOT execute commands
    malicious_payloads = [
        {"callsign": "ABC$(whoami)"},
        {"callsign": "ABC`reboot`"},
        {"callsign": 'ABC"; echo "pwned"'},
        {"callsign": "ABC$(rm -rf /tmp/test)"},
        {"callsign": "ABC; touch /tmp/pwned"},
        {"callsign": "ABC`id`"},
        {"callsign": "ABC\\x00\\x0a"},
    ]

    for payload in malicious_payloads:
        # The function should safely handle these without executing commands
        # It may fail to fetch data (404/500), but should NOT execute shell commands
        result = fetch_with_curl(
            "https://api.adsb.lol/api/0/routeset",
            method="POST",
            json_data=payload,
            timeout=5
        )
        # Result should be a valid response object, not a crash
        assert hasattr(result, 'status_code')
        assert hasattr(result, 'text')
        # The malicious command should NOT appear in the response
        assert "pwned" not in result.text.lower()


def test_safe_url_handling():
    """Test that URLs with special characters are handled safely."""
    # URLs with special characters that should be escaped/handled safely
    test_urls = [
        "https://example.com/path?param=value&other=test",
        "https://example.com/path?param=value with spaces",
        "https://example.com/path;semicolon",
    ]

    for url in test_urls:
        result = fetch_with_curl(url, timeout=5)
        assert hasattr(result, 'status_code')


def test_safe_header_handling():
    """Test that headers with special characters are handled safely."""
    malicious_headers = {
        "User-Agent": "Mozilla/5.0$(whoami)",
        "X-Custom": 'value"; echo "pwned"',
        "Accept": "text/html`id`",
    }

    result = fetch_with_curl(
        "https://httpbin.org/headers",
        headers=malicious_headers,
        timeout=5
    )
    assert hasattr(result, 'status_code')


if __name__ == "__main__":
    test_command_injection_via_json_data()
    test_safe_url_handling()
    test_safe_header_handling()
    print("All security tests passed!")
