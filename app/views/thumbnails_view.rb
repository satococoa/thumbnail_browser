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

  def remove_images
    @thumbnails.each do |thumb|
      thumb.removeFromSuperview
    end unless @thumbnails.empty?
    @thumbnails = []
  end

  # image_indexは0-3（このview内でのインデックス）
  def display_image_with_index(image, image_index)
    @thumbnails[image_index].removeFromSuperview unless @thumbnails[image_index].nil?

    img_view = UIImageView.alloc.initWithImage(image).tap do |v|
      v.contentMode = UIViewContentModeScaleAspectFit
      v.layer.borderColor = UIColor.orangeColor.CGColor
      v.layer.borderWidth = 0
      v.whenTapped do
        delegate.thumbnail_tapped(self, image_index)
      end
    end
    addSubview(img_view)
    @thumbnails[image_index] = img_view
  end

end