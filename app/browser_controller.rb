class BrowserController < UIViewController
  include BW::KVO

  HOME_URL = 'http://satococoa.github.com/'

  def loadView
    if super
      @loading_count = 0

      @browser = UIWebView.new.tap do |v|
        v.backgroundColor = UIColor.whiteColor
        v.frame = [[0, 0], [320, 460-44*2]]
        v.delegate = self
      end
      view.addSubview(@browser)
      navigationController.toolbarHidden = false

      # ツールバー、URLバーを配置
      setup_browser_parts
    end
    self
  end

  def viewDidLoad
    req = NSURLRequest.requestWithURL(NSURL.URLWithString(HOME_URL))
    @browser.loadRequest(req)
  end

  def go_back
    @browser.goBack if @browser.canGoBack
  end

  def go_forward
    @browser.goForward if @browser.canGoForward
  end

  def stop_loading
    @browser.stopLoading
  end

  def refresh
    @browser.reload
  end

  def webView(webView, shouldStartLoadWithRequest:request, navigationType:navigationType)
    true
  end

  def webViewDidStartLoad(webView)
    loading_changed(webView)
  end

  def webViewDidFinishLoad(webView)
    loading_changed(webView)
  end

  def webView(webView, didFailLoadWithError:error)
    loading_changed(webView)
    p error.code, error.domain, error.userInfo, error.localizedDescription
    App.alert(error.localizedDescription) if error.code != NSURLErrorCancelled
  end

  def textFieldShouldReturn(textField)
    url = NSURL.URLWithString(textField.text)
    req = NSURLRequest.requestWithURL(url)
    @browser.loadRequest(req)
    textField.resignFirstResponder
    true
  end

  private
  def setup_browser_parts
    # URLバー
    @url_field = UITextField.alloc.initWithFrame([[0, 0], [300, 31]]).tap do |f|
      f.font = UIFont.systemFontOfSize(14)
      f.borderStyle = UITextBorderStyleRoundedRect
      f.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter
      f.autocorrectionType = UITextAutocorrectionTypeNo
      f.keyboardType = UIKeyboardTypeURL
      f.returnKeyType = UIReturnKeyGo
      f.delegate = self
    end
    navigationItem.titleView = @url_field

    # ツールバー
    @back_button = UIBarButtonItem.alloc.initWithBarButtonSystemItem(101, target:self, action:'go_back').tap do |b|
      b.style = UIBarButtonItemStyleBordered
      b.enabled = false
    end
    @forward_button = UIBarButtonItem.alloc.initWithBarButtonSystemItem(102, target:self, action:'go_forward').tap do |b|
      b.style = UIBarButtonItemStyleBordered
      b.enabled = false
    end
    @spacer = UIBarButtonItem.alloc.initWithBarButtonSystemItem(UIBarButtonSystemItemFlexibleSpace, target:nil, action:nil)
    @refresh_button = UIBarButtonItem.alloc.initWithBarButtonSystemItem(UIBarButtonSystemItemRefresh, target:self, action:'refresh').tap do |b|
      b.style = UIBarButtonItemStyleBordered
    end
    @stop_button = UIBarButtonItem.alloc.initWithBarButtonSystemItem(UIBarButtonSystemItemStop, target:self, action:'stop_loading').tap do |b|
      b.style = UIBarButtonItemStyleBordered
    end

    self.toolbarItems = [
      @back_button,
      @forward_button,
      @spacer,
      @refresh_button
    ]
  end

  def loading_changed(webView)
    if webView.loading?
      if @loading_count == 0
        UIApplication.sharedApplication.networkActivityIndicatorVisible = true
        self.toolbarItems = [
          @back_button,
          @forward_button,
          @spacer,
          @stop_button
        ]
      end
      @loading_count += 1
    else
      @loading_count -= 1 if @loading_count > 0
      if @loading_count == 0
        @back_button.enabled = webView.canGoBack
        @forward_button.enabled = webView.canGoForward
        self.toolbarItems = [
          @back_button,
          @forward_button,
          @spacer,
          @refresh_button
        ]
        unless webView.request.mainDocumentURL.nil?
          @url_field.text = webView.request.mainDocumentURL.absoluteString
        end
        UIApplication.sharedApplication.networkActivityIndicatorVisible = false
      end
    end
  end
end