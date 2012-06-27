class ImagesController < UIViewController
  # 画像のURL(NSURL)の入った配列
  attr_accessor :images

  def loadView
    if super
      view.backgroundColor = UIColor.darkGrayColor

      @images_view = ImagesView.alloc.initWithFrame(content_frame)
      view.addSubview(@images_view)
      
      # 閉じるボタン
      @images_view.close_button.when(UIControlEventTouchUpInside) do
        self.dismissModalViewControllerAnimated(true)
      end
    end
    self
  end

  def viewWillAppear(animated)
    @images_view.images = @images
    @images_view.setNeedsDisplay
    # とりあえず表示
    # TODO: あとでviewでちゃんとやる
    # req = NSURLRequest.requestWithURL(@images.last)
    # @image_view.setImageWithURLRequest(req,
    #   placeholderImage:LOADING_IMAGE,
    #   success:lambda {|req, res, img| p img },
    #   failure:lambda {|req, res, error| log_error error }
    # )
  end
end