class ThumbnailsController < UIViewController
  attr_accessor :url

  def loadView
    if super
      view.backgroundColor = UIColor.darkGrayColor

      # 画像を取得して表示するキュー
      @queue = NSOperationQueue.new

      @image_view = UIImageView.alloc.initWithFrame([[10, 10], [300, 396]]).tap do |img|
        img.backgroundColor = UIColor.whiteColor
      end
      view.addSubview(@image_view)

      @thumbnail_view = UIScrollView.alloc.initWithFrame([[0, 416], [320, 44]]).tap do |sc|
        sc.pagingEnabled = true
        sc.alpha = 0.8
        sc.backgroundColor = UIColor.blackColor
      end
      view.addSubview(@thumbnail_view)
      
      # 閉じるボタン
      close_button = UIButton.buttonWithType(UIButtonTypeRoundedRect).tap do |b|
        b.setTitle('閉じる', forState:UIControlStateNormal)
        b.frame = [[20, 374], [60, 30]]
        b.alpha = 0.8
        b.addTarget(self, action:'close', forControlEvents:UIControlEventTouchUpInside)
      end
      view.addSubview(close_button)

    end
    self
  end

  def viewWillAppear(animated)
    #TODO: 同じURLを開いたときは画像を再取得したくない
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
          req = NSURLRequest.requestWithURL(url)
          opr = AFImageRequestOperation.imageRequestOperationWithRequest(req,
            success:lambda {|image|
              # 画像を読み込み、viewに追加
              p image
            })
          @queue.addOperation(opr)
        end
      },
      failure:lambda {|operation, error|
        p "Operation Error:"
        p error.code, error.domain, error.userInfo, error.localizedDescription
      }
    )
    @queue.addOperation(operation)
  end

  def close
    @queue.cancelAllOperations
    self.dismissModalViewControllerAnimated(true)
  end
end