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
        # 正規表現ではなくしたい
        images = str.scan(
          %r!\<a +href=(?:"|')?([^'"<>]+?\.(?:png|jpg|jpeg|gif))(?:"|')?.*?\>!m).to_a
        unless images.empty?
          images.each do |img|
            url = NSURL.URLWithString(img[0])
            url = NSURL.URLWithString(url.path, relativeToURL:@url) if url.scheme !~ /^https?$/
            p "URL: #{url.absoluteString}"
          end
        end
      },
      failure:lambda {|operation, error|
        p "Operation Error: #{error}"
      })
    operation.start
  end

  def close
    self.dismissModalViewControllerAnimated(true)
  end

end