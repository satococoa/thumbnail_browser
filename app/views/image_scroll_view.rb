class ImageScrollView < UIScrollView
  attr_accessor :image_view

  def initWithFrame(rect)
    if super
      self.showsVerticalScrollIndicator = false
      self.showsHorizontalScrollIndicator = false
      self.bouncesZoom = true
      self.decelerationRate = UIScrollViewDecelerationRateFast
      self.delegate = self
    end
    self
  end

  def layoutSubviews
    size = bounds.size

    # 画像を中心に置く
    @image_view.origin.x = if @image_view.size.width < size.width
      (size.width - @image_view.size.width) / 2
    else
      0
    end
    @image_view.origin.y = if @image_view.size.height < size.height
      (size.height - @image_view.size.height) / 2
    else
      0
    end
  end

  def viewForZoomingInScrollView(scrollView)
    @image_view
  end

  def display_image(image)
    @image_view.removeFromSuperview unless @image_view.nil?

    # リセット
    self.zoomScale = 1

    @image_view = UIImageView.alloc.initWithImage(image)
    addSubview(@image_view)

    self.contentSize = image.size
    set_max_min_zoom_scales_for_current_bounds
    self.zoomScale = minimumZoomScale
  end

  private
  def set_max_min_zoom_scales_for_current_bounds
    bounds_size = bounds.size
    image_size = @image_view.bounds.size

    p "[width]bounds_size: #{bounds_size.width}, image_size: #{image_size.width}"
    p "[height]bounds_size: #{bounds_size.height}, image_size: #{image_size.height}"

    x_scale = bounds_size.width.to_f / image_size.width.to_f
    y_scale = bounds_size.height.to_f / image_size.height.to_f

    p "y: #{y_scale}, x: #{x_scale}"

    min_scale = [x_scale, y_scale].min
    max_scale = 1.0 / UIScreen.mainScreen.scale

    p "min: #{min_scale}, max: #{max_scale}"

    min_scale = max_scale if min_scale > max_scale
    self.maximumZoomScale = max_scale
    self.minimumZoomScale = min_scale
  end
end