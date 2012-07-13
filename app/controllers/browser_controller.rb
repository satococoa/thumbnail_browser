class BrowserController < UIViewController
  include BW::KVO

  attr_accessor :image_urls, :loading_count

  # HOME_URL = 'http://satococoa.github.com/'
  # HOME_URL = 'http://burusoku-vip.com/archives/1280150.html'
  # HOME_URL = 'http://simapantu.blog130.fc2.com/blog-entry-506.html'
  # HOME_URL = 'http://nijigazo.2chblog.jp/archives/52259441.html'
  HOME_URL = 'http://blog.livedoor.jp/darkm/archives/51420219.html'

  def init
    if super
      @loading_count = 0
      @image_urls = []
    end
    self
  end

  def didReceiveMemoryWarning
    p 'Memory Warning!! on BrowserController'
    super
  end

  def loadView
    self.view = UIView.new
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
  end

  def viewWillAppear(animated)
    super
    # KVO
    start_observing

    if @browser.request.nil?
      req = NSURLRequest.requestWithURL(NSURL.URLWithString(HOME_URL))
      @browser.loadRequest(req)
    end
  end

  def viewWillDisappear(animated)
    super
    unobserve_all
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

  def open_images_view
    @images_controller ||= ImagesController.new
    @images_controller.parent = self
    @images_controller.image_urls = @image_urls.uniq
    presentModalViewController(@images_controller, animated:true)
  end

  def close_images(images)
    images.parent = nil
    images.dismissModalViewControllerAnimated(true)
  end

  def webView(webView, shouldStartLoadWithRequest:request, navigationType:navigationType)
    if navigationType != UIWebViewNavigationTypeOther
      @url_field.text = request.mainDocumentURL.absoluteString
    end
    true
  end

  def webViewDidStartLoad(webView)
    self.loading_count += 1
  end

  def webViewDidFinishLoad(webView)
    self.loading_count -= 1 if self.loading_count > 0
  end

  def webView(webView, didFailLoadWithError:error)
    self.loading_count -= 1 if self.loading_count > 0
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
    @images_button = UIBarButtonItem.alloc.initWithTitle('IMG', style:UIBarButtonItemStyleBordered, target:self, action:'open_images_view').tap do |b|
      b.enabled = false
    end

    self.toolbarItems = [
      @back_button,
      @forward_button,
      @spacer,
      @images_button,
      @spacer,
      @refresh_button
    ]
  end

  def start_observing
    # image属性をObserve
    observe(self, 'image_urls') do |old_value, new_value|
      @images_button.enabled = !new_value.empty?
    end

    # loading_count属性をObserve
    observe(self, 'loading_count') do |old_value, new_value|
      if old_value > 0 && new_value == 0
        UIApplication.sharedApplication.networkActivityIndicatorVisible = false
        @back_button.enabled = @browser.canGoBack
        @forward_button.enabled = @browser.canGoForward
        self.toolbarItems = [
          @back_button,
          @forward_button,
          @spacer,
          @images_button,
          @spacer,
          @refresh_button
        ]
        # パースが必要なので非同期にする
        html = @browser.stringByEvaluatingJavaScriptFromString('document.documentElement.outerHTML')
        Dispatch::Queue.main.async {
          doc = Document.new(html)
          self.image_urls = doc.image_urls
        }
      else old_value == 0 && new_value > 0
        UIApplication.sharedApplication.networkActivityIndicatorVisible = true
        self.toolbarItems = [
          @back_button,
          @forward_button,
          @spacer,
          @images_button,
          @spacer,
          @stop_button
        ]
        self.image_urls = []
      end
    end
  end
end