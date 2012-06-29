class AppDelegate
  def application(application, didFinishLaunchingWithOptions:launchOptions)
    browser_controller = BrowserController.new
    navigation_controller = UINavigationController.alloc.initWithRootViewController(browser_controller)
    @window = UIWindow.alloc.initWithFrame(App.bounds)
    @window.rootViewController = navigation_controller
    @window.makeKeyAndVisible
    true
  end

  def applicationDidReceiveMemoryWarning(application)
    p 'Memory Warning!! on AppDelegate'
  end
end
