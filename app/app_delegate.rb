class AppDelegate
  def application(application, didFinishLaunchingWithOptions:launchOptions)
    browser_controller = BrowserController.new
    @window = UIWindow.alloc.initWithFrame(App.bounds)
    @window.rootViewController = browser_controller
    @window.makeKeyAndVisible
    true
  end
end
