class ThumbnailsController < UIViewController
  attr_accessor :url

  def loadView
    if super
      view.backgroundColor = UIColor.darkGrayColor
      close_button = UIButton.buttonWithType(UIButtonTypeRoundedRect).tap do |b|
        b.setTitle('閉じる', forState:UIControlStateNormal)
        b.frame = [[10, 374], [60, 30]]
        b.alpha = 0.8
        b.addTarget(self, action:'close', forControlEvents:UIControlEventTouchUpInside)
      end
      view.addSubview(close_button)
    end
    self
  end

  def viewWillAppear(animated)
    super
    # 画像のURLのみを抜き出す
    request = NSURLRequest.requestWithURL(@url)
    operation = AFHTTPRequestOperation.alloc.initWithRequest(request)
    operation.setCompletionBlockWithSuccess(
      lambda {|operation, response|
        error_ptr = Pointer.new(:object)
        doc = GDataXMLDocument.alloc.initWithHTMLData(operation.responseData,
          options:0, error:error_ptr)
        error = error_ptr[0]
        unless error.nil?
          p error.code, error.domain, error.userInfo, error.localizedDescription
        end

        xpath = "//a[contains(@href, '.jpg') or contains(@href, '.jpeg') or contains(@href, '.png') or contains(@href, '.gif')]/@href"

        error_ptr = Pointer.new(:object)
        links = doc.nodesForXPath(xpath, error:error_ptr)
        unless error.nil?
          p error.code, error.domain, error.userInfo, error.localizedDescription
        end

        links.each do |link|
          url = NSURL.URLWithString(link.stringValue)
          url = NSURL.URLWithString(url.path, relativeToURL:@url) if url.scheme !~ /^https?$/
          p "URL: #{url.absoluteString}"
        end
      },
      failure:lambda {|operation, error|
        p "Operation Error:"
        p error.code, error.domain, error.userInfo, error.localizedDescription
      })
    operation.start
  end

  def close
    self.dismissModalViewControllerAnimated(true)
  end
end