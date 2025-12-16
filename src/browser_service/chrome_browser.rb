require 'ferrum'

module BrowserService
  class ChromeBrowser < BrowserService::Browser

    def create_browser()
      browser_path =  if running_on_macos?
                        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
                      else
                        "/usr/bin/google-chrome-stable"
                      end
      browser = Ferrum::Browser.new(
        browser_path: browser_path, headless: true, 
        pending_connection_errors: false, process_timeout: 60, 
        xvfb: true, browser_options: { 'no-sandbox': nil })
      browser
    end
  end
end