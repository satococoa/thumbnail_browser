class BrowserController < UIViewController
  include BW::KVO

  attr_accessor :images

  # HOME_URL = 'http://satococoa.github.com/'
  HOME_URL = 'http://news4vip.livedoor.biz/archives/51357270.html'

  def loadView
    if super
      @loading_count = 0
      @images = []

      @browser = UIWebView.new.tap do |v|
        v.backgroundColor = UIColor.whiteColor
        v.frame = [[0, 0], [320, 460-44*2]]
        v.delegate = self
        v.scalesPageToFit = true
      end
      view.addSubview(@browser)
      navigationController.toolbarHidden = false

      # ツールバー、URLバーを配置
      setup_browser_parts

      # image属性をObserve
      observe(self, 'images') do |old_value, new_value|
        @thumbnail_button.enabled = !new_value.empty?
      end
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

  def open_thumbnail_view
    @thumbnails_controller ||= ThumbnailsController.new
    @thumbnails_controller.images = @images
    presentModalViewController(@thumbnails_controller, animated:true)
  end

  def webView(webView, shouldStartLoadWithRequest:request, navigationType:navigationType)
    if navigationType != UIWebViewNavigationTypeOther
      @url_field.text = request.mainDocumentURL.absoluteString
    end
    true
  end

  def webViewDidStartLoad(webView)
    loading_changed_loading(webView)
  end

  def webViewDidFinishLoad(webView)
    loading_changed_not_loading(webView)
  end

  def webView(webView, didFailLoadWithError:error)
    loading_changed_not_loading(webView)
    log_error error
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
      f.text = HOME_URL
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
    @thumbnail_button = UIBarButtonItem.alloc.initWithTitle('THUMB', style:UIBarButtonItemStyleBordered, target:self, action:'open_thumbnail_view').tap do |b|
      b.enabled = false
    end

    self.toolbarItems = [
      @back_button,
      @forward_button,
      @spacer,
      @thumbnail_button,
      @spacer,
      @refresh_button
    ]
  end

  def loading_changed_loading(webView)
    if @loading_count == 0
      UIApplication.sharedApplication.networkActivityIndicatorVisible = true
      self.toolbarItems = [
        @back_button,
        @forward_button,
        @spacer,
        @thumbnail_button,
        @spacer,
        @stop_button
      ]
      self.images = []
    end
    @loading_count += 1
  end

  def loading_changed_not_loading(webView)
   if @loading_count > 0
    @loading_count -= 1
    if @loading_count == 0
      @back_button.enabled = webView.canGoBack
      @forward_button.enabled = webView.canGoForward
      self.toolbarItems = [
        @back_button,
        @forward_button,
        @spacer,
        @thumbnail_button,
        @spacer,
        @refresh_button
      ]
      UIApplication.sharedApplication.networkActivityIndicatorVisible = false
      # パースが必要なので非同期にする
      html = webView.stringByEvaluatingJavaScriptFromString('document.documentElement.outerHTML')
      Dispatch::Queue.main.async {
        doc = Document.new(html)
        self.images = doc.image_urls
      }
    end
  end
  end
end