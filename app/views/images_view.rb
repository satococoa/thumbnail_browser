class ImagesView < UIView
  attr_accessor :images
  attr_reader :stage, :thumbnails, :close_button

  LOADING_IMAGE = UIImage.imageNamed('loading.png')

  def initWithFrame(rect)
    if super
      @images = []
      self.backgroundColor = UIColor.darkGrayColor
      @stage = UIScrollView.alloc.initWithFrame([[0, 0], [320, 411]]).tap do |v|
        v.pagingEnabled = true
        # v.contentInset = [10, 10, 10, 10]
      end
      @thumbnails = UIScrollView.alloc.initWithFrame([[0, 411], [320, 49]]).tap do |v|
        v.pagingEnabled = true
        v.backgroundColor = UIColor.blackColor
        # v.contentInset = [4, 50, 5, 50]
      end
      @close_button = UIButton.buttonWithType(UIButtonTypeRoundedRect).tap do |b|
        b.setTitle('閉じる', forState:UIControlStateNormal)
        b.frame = [[20, 374], [60, 30]]
        b.alpha = 0.8
      end
      
      addSubview(@stage)
      addSubview(@thumbnails)
      addSubview(@close_button)
    end
    self
  end

  def drawRect(rect)
    @stage.contentSize = [320*@images.count, 411-20] # 20はinset分
    @thumbnails.contentSize = [320*(1 + @images.count/4), 40]
    @images.each_with_index do |img, i|
      req = NSURLRequest.requestWithURL(img)

      stage_offset = i * 320 + 10
      stage_image = UIImageView.alloc.initWithFrame([[stage_offset, 10], [300, 411-20]]).tap do |stg|
        stg.contentMode = UIViewContentModeScaleAspectFit
        stg.setImageWithURLRequest(req,
          placeholderImage:LOADING_IMAGE,
          success:lambda {|req, res, img| p img },
          failure:lambda {|req, res, error| log_error error }
        )
      end
      @stage.addSubview(stage_image)

      thumb_offset = i/4 * 320 + i%4 * 60 + 50
      thumb_image = UIImageView.alloc.initWithFrame([[thumb_offset, 5], [40, 40]]).tap do |thumb|
        thumb.contentMode = UIViewContentModeScaleAspectFit
        thumb.setImageWithURLRequest(req,
          placeholderImage:LOADING_IMAGE,
          success:lambda {|req, res, img| p img },
          failure:lambda {|req, res, error| log_error error }
        )
      end
      @thumbnails.addSubview(thumb_image)
    end
  end

end