class ImagesController < UIViewController
  # 画像のURL(NSURL)の入った配列
  attr_accessor :images

  LOADING_IMAGE = UIImage.imageNamed('loading.png')

  def loadView
    if super
      @thumb_views = []
      view.backgroundColor = UIColor.darkGrayColor

      @stage = UIScrollView.alloc.initWithFrame([[0, 0], [320, 411]]).tap do |v|
        v.pagingEnabled = true
        v.delegate = self
      end
      view.addSubview(@stage)

      @thumbnails = UIScrollView.alloc.initWithFrame([[0, 411], [320, 49]]).tap do |v|
        v.pagingEnabled = true
        v.backgroundColor = UIColor.blackColor
      end
      view.addSubview(@thumbnails)

      @close_button = UIButton.buttonWithType(UIButtonTypeRoundedRect).tap do |b|
        b.setTitle('閉じる', forState:UIControlStateNormal)
        b.frame = [[10, 374], [60, 30]]
        b.alpha = 0.8
        b.when(UIControlEventTouchUpInside) do
          self.dismissModalViewControllerAnimated(true)
        end
      end
      view.addSubview(@close_button)
    end
    self
  end

  def viewWillAppear(animated)
    super
    load_images
  end

  def scrollViewDidScroll(scrollView)
    image_no = (scrollView.contentOffset.x/320.0).ceil
    @selected.layer.borderWidth = 0 unless @selected.nil?
    thumb = @thumbnails.subviews[image_no]
    thumb.layer.borderWidth = 2
    @selected = thumb
  end

  private
  def load_images
    [@stage, @thumbnails].each do |container|
      container.subviews.each {|v| v.removeFromSuperview }
    end

    @stage.contentSize = [320*@images.count, 411-20]
    @thumbnails.contentSize = [320*(@images.count/4.0).ceil, 40]
    @images.each_with_index do |img, i|
      req = NSURLRequest.requestWithURL(img)

      stage_offset = i * 320
      stage_image = UIImageView.alloc.initWithFrame([[stage_offset+10, 10], [300, 411-20]]).tap do |stg|
        stg.contentMode = UIViewContentModeScaleAspectFit
        stg.setImageWithURLRequest(req,
          placeholderImage:LOADING_IMAGE,
          success:lambda {|req, res, img| p img },
          failure:lambda {|req, res, error| log_error error }
        )
      end
      @stage.addSubview(stage_image)

      thumb_offset = i/4 * 320 + i%4 * 60
      thumb_image = UIImageView.alloc.initWithFrame([[thumb_offset+50, 5], [40, 40]]).tap do |thumb|
        thumb.contentMode = UIViewContentModeScaleAspectFit
        thumb.layer.borderColor = UIColor.brownColor.CGColor
        thumb.setImageWithURLRequest(req,
          placeholderImage:LOADING_IMAGE,
          success:lambda {|req, res, img| p img },
          failure:lambda {|req, res, error| log_error error }
        )
        thumb.whenTapped { @stage.setContentOffset([stage_offset, 0], animated:true) }
      end
      @thumbnails.addSubview(thumb_image)
    end
  end
end