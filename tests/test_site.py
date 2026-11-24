import os
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen

import pytest
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait


BASE_URL = os.environ.get("SITE_URL", "http://site")
RESULTS_DIR = Path(os.environ.get("RESULTS_DIR", "/results"))


def site_ready(_):
    try:
        with urlopen(BASE_URL, timeout=2) as response:
            return response.status == 200
    except (OSError, URLError):
        return False


@pytest.fixture(scope="module")
def browser():
    WebDriverWait(None, 30).until(site_ready, "nginx did not become ready")
    options = webdriver.ChromeOptions()
    options.binary_location = "/usr/bin/chromium"
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--window-size=1200,850")
    with webdriver.Chrome(service=Service("/usr/bin/chromedriver"), options=options) as driver:
        yield driver


@pytest.fixture
def page(browser):
    browser.get(BASE_URL)
    return browser


def test_title(page):
    assert page.title == "Cloud Computing Lab | FA23-BCT-021"


def test_heading(page):
    assert page.find_element(By.TAG_NAME, "h1").text == "Muhammad Ahmad Shabaan"
    assert "FA23-BCT-021" in page.find_element(By.TAG_NAME, "main").text


def test_button_click(page):
    page.find_element(By.ID, "show-message").click()
    assert page.find_element(By.ID, "click-message").text == "The cloud lab page is running."


def test_text_submission(page):
    value = "Selenium verified this form."
    page.find_element(By.ID, "entry").send_keys(value)
    page.find_element(By.CSS_SELECTOR, "button[type=submit]").click()
    assert page.find_element(By.ID, "submitted-text").text == value
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    assert page.save_screenshot(str(RESULTS_DIR / "selenium-form.png"))
