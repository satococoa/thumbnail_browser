class ImagesController < UIViewController
  # 画像のURL(NSURL)の入った配列
  attr_accessor :images

  LOADING_IMAGE = UIImage.imageNamed('loading.png')

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
    # とりあえず表示
    # TODO: あとでviewでちゃんとやる
    req = NSURLRequest.requestWithURL(@images.last)
    @image_view.setImageWithURLRequest(req,
      placeholderImage:LOADING_IMAGE,
      success:lambda {|req, res, img| p img },
      failure:lambda {|req, res, error| log_error error }
    )
  end

  def close
    @queue.cancelAllOperations
    self.dismissModalViewControllerAnimated(true)
  end
end