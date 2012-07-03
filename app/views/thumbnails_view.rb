class ThumbnailsView < UIView
  attr_accessor :index, :delegate

  LOADING_IMAGE = UIImage.imageNamed('loading.png')
  ERROR_IMAGE = UIImage.imageNamed('error.png')

  def initWithFrame(rect)
    if super
      @thumbnails = []
    end
    self
  end

  def layoutSubviews
    @thumbnails.each_with_index do |thumb, index|
      offset = index%4 * 60 + 50
      thumb.frame = [[offset, 5], [40, 40]]
    end
  end

  def select_image(image_index)
    @thumbnails[image_index].layer.borderWidth = 2
  end

  def deselect_image(image_index)
    @thumbnails[image_index].layer.borderWidth = 0
  end

  def display_images_with_urls(urls)
    @thumbnails.each do |thumb|
      thumb.removeFromSuperview
    end unless @thumbnails.empty?

    @thumbnails = []
    urls.each_with_index do |url, image_index|
      display_image_with_url(url, image_index)
    end
  end

  # image_indexは0-3（このview内でのインデックス）
  def display_image_with_url(url, image_index)
    @thumbnails[image_index].removeFromSuperview unless @thumbnails[image_index].nil?

    img_view = UIImageView.new.tap do |v|
      v.contentMode = UIViewContentModeScaleAspectFit
      v.layer.borderColor = UIColor.orangeColor.CGColor
      v.layer.borderWidth = 0
      v.whenTapped do
        delegate.thumbnail_tapped(self, image_index)
      end
      req = NSURLRequest.requestWithURL(url)
      v.setImageWithURLRequest(req, 
        placeholderImage:LOADING_IMAGE,
        success:lambda {|req, res, image| },
        failure:lambda {|req, res, error|
          log_error error
          v.image = ERROR_IMAGE
        }
      )
    end
    addSubview(img_view)
    @thumbnails[image_index] = img_view
  end

end