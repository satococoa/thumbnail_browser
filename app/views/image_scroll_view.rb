class ImageScrollView < UIScrollView
  attr_accessor :index

  LOADING_IMAGE = UIImage.imageNamed('loading.png')
  ERROR_IMAGE = UIImage.imageNamed('error.png')

  def initWithFrame(rect)
    if super
      self.showsVerticalScrollIndicator = false
      self.showsHorizontalScrollIndicator = false
      self.bouncesZoom = true
      self.decelerationRate = UIScrollViewDecelerationRateFast
      self.delegate = self
      double_tap = UITapGestureRecognizer.alloc.initWithTarget(
        self, action:'toggle_zoom').tap do |g|
        g.numberOfTapsRequired = 2
      end
      self.addGestureRecognizer(double_tap)
    end
    self
  end

  def toggle_zoom
    if self.zoomScale < maximumZoomScale
      self.setZoomScale(maximumZoomScale, animated:true)
    else
      self.setZoomScale(minimumZoomScale, animated:true)
    end
  end

  def layoutSubviews
    size = bounds.size

    # 画像を中心に置く
    x = if @image_view.size.width < size.width
      (size.width - @image_view.size.width).to_f / 2.0
    else
      0
    end
    y = if @image_view.size.height < size.height
      (size.height - @image_view.size.height).to_f / 2.0
    else
      0
    end
    @image_view.frame = [[x, y], @image_view.size]
  end

  def viewForZoomingInScrollView(scrollView)
    @image_view
  end

  def display_image_with_url(url)
    @image_view.removeFromSuperview unless @image_view.nil?

    # リセット
    self.zoomScale = 1

    req = NSURLRequest.requestWithURL(url)
    @image_view = UIImageView.new.tap do |v|
      v.contentMode = UIViewContentModeCenter
      v.frame = [[0, 0], self.bounds.size]
      v.setImageWithURLRequest(req, 
        placeholderImage:LOADING_IMAGE,
        success:lambda {|req, res, image|
          v.contentMode = UIViewContentModeScaleAspectFit
          setup_size
        },
        failure:lambda {|req, res, error|
          log_error error
          v.image = ERROR_IMAGE
          setup_size
        }
      )
    end
    addSubview(@image_view)
    setup_size
  end

  private
  def setup_size
    return if @image_view.nil?
    self.contentSize = @image_view.image.size
    set_max_min_zoom_scales_for_current_bounds
    self.zoomScale = minimumZoomScale
  end

  def set_max_min_zoom_scales_for_current_bounds
    bounds_size = bounds.size
    image_size = @image_view.bounds.size

    x_scale = bounds_size.width.to_f / image_size.width.to_f
    y_scale = bounds_size.height.to_f / image_size.height.to_f

    min_scale = [x_scale, y_scale].min
    # 2.5倍まで拡大できるようにする
    # retinaの考慮を入れて。
    max_scale = 2.5 / UIScreen.mainScreen.scale

    min_scale = max_scale if min_scale > max_scale
    self.maximumZoomScale = max_scale
    self.minimumZoomScale = min_scale
  end
end