class BrowserController < UIViewController
  def loadView
    if super
      @browser = UIWebView.new.tap do |v|
        v.backgroundColor = UIColor.whiteColor
        v.frame = [[0, 0], [320, 460-44*2]]
        v.delegate = self
      end
      view.addSubview(@browser)
      navigationController.toolbarHidden = false
    end
    self
  end

  def viewDidLoad
    req = NSURLRequest.requestWithURL(NSURL.URLWithString('http://satococoa.github.com/'))
    @browser.loadRequest(req)
  end
end