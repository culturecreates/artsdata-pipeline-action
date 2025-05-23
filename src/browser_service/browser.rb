module BrowserService
  class Browser
    def create_browser()
      raise NotImplementedError, 'Subclasses must implement create_browser'
    end

    def running_on_macos?
      RbConfig::CONFIG['host_os'] =~ /darwin|mac os/
    end
  end
end