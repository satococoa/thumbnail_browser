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
        str = operation.responseString
        error_ptr = Pointer.new(:object)
        parser = HTMLParser.alloc.initWithString(str, error:error_ptr)

        error = error_ptr[0]
        unless error.nil?
          p error.code, error.domain, error.userInfo, error.localizedDescription
          return
        end

        body = parser.body
        links = body.findChildTags('a')
        links.each do |link|
          url = NSURL.URLWithString(link.getAttributeNamed('href'))
          next if url.nil?
          next unless ['jpg', 'jpeg', 'png', 'gif'].include?(url.pathExtension)
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