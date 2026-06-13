import sys
import time
import random
from playwright.sync_api import sync_playwright

def human_click(locator):
    try:
        locator.hover()
        time.sleep(random.uniform(0.15, 0.4))  # Pause before click
        locator.click()
    except Exception:
        locator.click(timeout=1000)

def human_type(locator, text):
    locator.focus()
    # Select all and delete to clear existing text
    locator.press("Control+A")
    locator.press("Backspace")
    time.sleep(random.uniform(0.1, 0.25))
    for char in text:
        locator.press(char)
        time.sleep(random.uniform(0.03, 0.09))  # Typing speed variation

def handle_consent(page):
    try:
        consent_selectors = [
            'button[aria-label="Accept the use of cookies and other data for the purposes described"]',
            'button[aria-label="Accept all"]',
            'button:has-text("Accept all")',
            'button:has-text("I agree")',
            '#buttons ytd-button-renderer:has-text("Accept all")',
        ]
        for sel in consent_selectors:
            locator = page.locator(sel)
            if locator.count() > 0:
                human_click(locator)
                break
    except Exception:
        pass

def get_browser_and_context(p, headless=False):
    # Standard realistic user agent and stealth launch args
    user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    args = [
        "--start-maximized",
        "--remote-debugging-port=9222",
        "--disable-blink-features=AutomationControlled"
    ]
    
    # Try connecting to an existing browser instance running on debugging port 9222
    try:
        browser = p.chromium.connect_over_cdp("http://localhost:9222")
        print("Connected to existing browser instance on port 9222.")
        context = browser.contexts[0]
        return browser, context, True
    except Exception:
        print("No existing browser found. Launching new instance on port 9222...")
        user_data_dir = "D:\\Daksh\\Coding\\Python\\Personal Projects (fsociety)\\Zournia\\zournia_pc\\chrome_user_data"
        browser_context = p.chromium.launch_persistent_context(
            user_data_dir,
            headless=headless,
            no_viewport=True,
            user_agent=user_agent,
            args=args
        )
        return browser_context, browser_context, False

def play_youtube(query):
    with sync_playwright() as p:
        print(f"Searching YouTube for: {query}")
        browser, context, connected = get_browser_and_context(p)
        page = context.new_page()
        
        # Navigate to YouTube
        page.goto("https://www.youtube.com")
        handle_consent(page)
        
        # Wait for search box and fill
        try:
            page.wait_for_selector('input[name="search_query"]', timeout=3000)
        except Exception:
            pass
            
        search_box = page.locator('input[name="search_query"]')
        if search_box.count() > 0:
            human_type(search_box, query)
            time.sleep(random.uniform(0.2, 0.4))
            search_box.press("Enter")
        
        # Wait for search results to load
        print("Waiting for search results...")
        try:
            page.wait_for_selector('a#video-title', timeout=3000)
        except Exception:
            pass
        
        # Click the first video that is a renderer link
        video_links = page.locator('ytd-video-renderer a#video-title')
        if video_links.count() == 0:
            video_links = page.locator('a#video-title')
            
        if video_links.count() > 0:
            first_video = video_links.first
            title = first_video.inner_text()
            print(f"Playing video: {title}")
            human_click(first_video)
            
            # Let it play (sleep loop to keep open)
            print("Video started. Keeping page open...")
            try:
                while True:
                    time.sleep(0.5)
                    if page.is_closed():
                        break
            except KeyboardInterrupt:
                pass
        else:
            print("No videos found.")
        
        try:
            if not page.is_closed():
                page.close()
        except Exception:
            pass
            
        if not connected:
            try:
                active_pages = [pg for pg in context.pages if not pg.is_closed()]
                if len(active_pages) == 0:
                    browser.close()
            except Exception:
                pass

def open_url(url):
    with sync_playwright() as p:
        print(f"Opening URL: {url}")
        browser, context, connected = get_browser_and_context(p)
        page = context.new_page()
        page.goto(url)
        
        try:
            while True:
                time.sleep(0.5)
                if page.is_closed():
                    break
        except KeyboardInterrupt:
            pass
            
        try:
            if not page.is_closed():
                page.close()
        except Exception:
            pass
            
        if not connected:
            try:
                active_pages = [pg for pg in context.pages if not pg.is_closed()]
                if len(active_pages) == 0:
                    browser.close()
            except Exception:
                pass

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python browser_agent.py <command> <arg>")
        sys.exit(1)
        
    cmd = sys.argv[1]
    arg = sys.argv[2]
    
    if cmd == "youtube":
        play_youtube(arg)
    elif cmd == "open":
        open_url(arg)
    else:
        print(f"Unknown command: {cmd}")
