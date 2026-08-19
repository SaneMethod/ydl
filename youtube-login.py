import os
import sys
import time
import base64
from pathlib import Path
from typing import Any

from cktotp import TOTP
from clarkbrowser import launch, launch_persistent_context


LOGIN_URL = (
    "https://accounts.google.com/ServiceLogin"
    "?service=youtube"
    "&continue=https%3A%2F%2Fwww.youtube.com%2F"
)


def required_environment(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"Required environment variable {name} is not set")
    return value


def current_totp(secret: str) -> str:
    """Generate a code through cktotp."""
    totp = TOTP(secret=secret, digits=6)

    return totp.at()


def visible(page: Any, selector: str) -> bool:
    try:
        return page.locator(selector).first.is_visible(timeout=2_000)
    except Exception:
        return False


def fill_first_visible(page: Any, selectors: list[str], value: str) -> bool:
    for selector in selectors:
        if visible(page, selector):
            page.locator(selector).first.fill(value)
            return True
    return False


def click_first_visible(page: Any, selectors: list[str]) -> bool:
    for selector in selectors:
        if visible(page, selector):
            page.locator(selector).first.click()
            return True
    return False


def wait_for_login_step(page: Any) -> None:
    page.wait_for_timeout(2_000)
    try:
        page.wait_for_load_state("domcontentloaded", timeout=15_000)
    except Exception:
        pass


def export_netscape_cookies(context: Any, destination: Path) -> None:
    cookies = context.cookies()
    if not any(
            cookie["domain"].lstrip(".").endswith(("youtube.com", "google.com"))
            for cookie in cookies
    ):
        raise RuntimeError("Login completed without receiving Google/YouTube cookies")

    temporary = destination.with_suffix(destination.suffix + ".tmp")
    temporary.parent.mkdir(parents=True, exist_ok=True)

    with temporary.open("w", encoding="utf-8", newline="\n") as cookie_file:
        cookie_file.write("# Netscape HTTP Cookie File\n")
        cookie_file.write("# Generated automatically; do not edit.\n")

        for cookie in cookies:
            domain = cookie["domain"]
            include_subdomains = "TRUE" if domain.startswith(".") else "FALSE"
            secure = "TRUE" if cookie.get("secure", False) else "FALSE"
            expires = int(cookie.get("expires", 0))
            if expires < 0:
                expires = 0

            value = str(cookie.get("value", "")).replace("\t", "%09").replace(
                "\n", "%0A"
            )
            cookie_file.write(
                "\t".join(
                    (
                        domain,
                        include_subdomains,
                        cookie.get("path", "/"),
                        secure,
                        str(expires),
                        cookie["name"],
                        value,
                    )
                )
                + "\n"
            )

    os.chmod(temporary, 0o777)
    temporary.replace(destination)


def login() -> None:
    username = required_environment("YOU_USER")
    password = required_environment("YOU_PASS")
    secret = base64.b32decode(os.environ.get("YOU_SECRET", "").replace(" ", "").strip())
    destination = Path(
        os.environ.get("YOUTUBE_COOKIES", "/config/youtube-cookies.txt")
    )
    profile = Path(
        os.environ.get(
            "YOUTUBE_BROWSER_PROFILE",
            "/config/clark-browser-profile",
        )
    )
    profile.mkdir(parents=True, exist_ok=True)

    browser = launch_persistent_context(profile,
        headless=True,
        args=[
            "--no-sandbox",
            "--disable-dev-shm-usage",
        ],
    )

    try:
        page = browser.new_page()
        page.goto(LOGIN_URL, wait_until="domcontentloaded", timeout=60_000)

        if "youtube.com" not in page.url:
            if not fill_first_visible(
                    page,
                    ['input[type="email"]', 'input[name="identifier"]'],
                    username,
            ):
                raise RuntimeError("Google username field was not available")

            click_first_visible(
                page,
                [
                    "#identifierNext button",
                    'button:has-text("Next")',
                ],
            )
            wait_for_login_step(page)

            if not fill_first_visible(
                    page,
                    ['input[type="password"]', 'input[name="Passwd"]'],
                    password,
            ):
                raise RuntimeError("Google password field was not available")

            click_first_visible(
                page,
                [
                    "#passwordNext button",
                    'button:has-text("Next")',
                ],
            )
            wait_for_login_step(page)

            otp_selectors = [
                'input[type="tel"]',
                'input[name="totpPin"]',
                'input[name="idvPin"]',
                'input[autocomplete="one-time-code"]',
            ]
            if any(visible(page, selector) for selector in otp_selectors):
                if not secret:
                    raise RuntimeError(
                        "Google requested TOTP, but YOU_SECRET is not set"
                    )

                if not fill_first_visible(
                        page,
                        otp_selectors,
                        current_totp(secret),
                ):
                    raise RuntimeError("Unable to fill the Google TOTP field")

                click_first_visible(
                    page,
                    [
                        'button:has-text("Next")',
                        'button:has-text("Verify")',
                        "#totpNext button",
                    ],
                )
                wait_for_login_step(page)

        page.goto(
            "https://www.youtube.com/",
            wait_until="domcontentloaded",
            timeout=60_000,
        )
        page.wait_for_timeout(3_000)

        if "accounts.google.com" in page.url:
            raise RuntimeError(
                "Google did not accept the automated login; an interactive "
                "challenge may be required"
            )

        export_netscape_cookies(page.context, destination)
        print(f"Refreshed YouTube cookies at {destination}")
    finally:
        browser.close()


if __name__ == "__main__":
    try:
        login()
    except Exception as error:
        print(f"YouTube login failed: {error}", file=sys.stderr)
        sys.exit(1)
