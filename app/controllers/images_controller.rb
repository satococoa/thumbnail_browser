class ImagesController < UIViewController
  # 画像のURL(NSURL)の入った配列
  attr_accessor :images

  LOADING_IMAGE = UIImage.imageNamed('loading.png')
  ERROR_IMAGE = UIImage.imageNamed('error.png')

  def loadView
    if super
      @image_queue = NSOperationQueue.new

      view.backgroundColor = UIColor.darkGrayColor

      @stage = UIScrollView.alloc.initWithFrame([[0, 0], [320, 460]]).tap do |v|
        v.pagingEnabled = true
        v.showsVerticalScrollIndicator = false
        v.showsHorizontalScrollIndicator = false
        v.delegate = self

        double_tap = UITapGestureRecognizer.new.tap do |g|
          g.numberOfTapsRequired = 2
        end
        v.addGestureRecognizer(double_tap)

        single_tap = UITapGestureRecognizer.alloc.initWithTarget(
          self, action:'toggle_hud:').tap do |g|
          g.requireGestureRecognizerToFail(double_tap)
        end
        v.addGestureRecognizer(single_tap)
      end
      view.addSubview(@stage)

      @thumbnails = UIScrollView.alloc.initWithFrame([[0, 411], [320, 49]]).tap do |v|
        v.pagingEnabled = true
        v.showsVerticalScrollIndicator = false
        v.showsHorizontalScrollIndicator = false
        v.backgroundColor = UIColor.blackColor
        v.alpha = 0.6
      end
      view.addSubview(@thumbnails)

      @close_button = UIButton.buttonWithType(UIButtonTypeRoundedRect).tap do |b|
        b.setTitle('閉じる', forState:UIControlStateNormal)
        b.frame = [[10, 374], [60, 30]]
        b.alpha = 0.6
        b.when(UIControlEventTouchUpInside) do
          self.dismissModalViewControllerAnimated(true)
        end
      end
      view.addSubview(@close_button)
    end
    self
  end

  def toggle_hud(gesture)
    if @thumbnails.alpha > 0
      UIView.animateWithDuration(0.5,
        animations:lambda {
          @thumbnails.alpha = 0
          @close_button.alpha = 0
        }
      )
    else
      @thumbnails.alpha = 0.6
      @close_button.alpha = 0.6
    end
  end

  def viewWillAppear(animated)
    super
    load_images
  end

  def viewDidDisappear(animated)
    super
    @image_queue.cancelAllOperations
  end

  def didReceiveMemoryWarning
    super
    p 'Memory Warning!! on ImagesController'
  end

  def scrollViewDidEndDragging(scrollView, willDecelerate:decelerate)
    end_scroll unless decelerate
  end

  def scrollViewDidEndDecelerating(scrollView)
    end_scroll
  end

  def scrollViewDidEndScrollingAnimation(scrollView)
    end_scroll
  end

  private
  def end_scroll
    image_index = (@stage.contentOffset.x/320.0).ceil
    select(image_index)
  end

  def select(image_index)
    deselect(@selected) unless @selected.nil?
    image_view = @image_views[image_index]
    @stage.setContentOffset([image_index*320, 0], animated:true)
    @thumbnails.setContentOffset([image_index/4*320, 0], animated:true)
    image_view[:thumb].layer.borderWidth = 2
    @selected = image_view
  end

  def deselect(image_view)
    image_view[:view].zoomScale = image_view[:view].minimumZoomScale
    image_view[:thumb].layer.borderWidth = 0
  end

  def load_images
    # [{url: u, image: UIImageView *image, thumb: UIImageView *thumb}, ...]
    @image_views = []
    [@stage, @thumbnails].each do |container|
      container.subviews.each {|v| v.removeFromSuperview }
    end

    @stage.contentSize = [320*@images.count, 460]
    @thumbnails.contentSize = [320*(@images.count/4.0).ceil, 40]
    @images.each_with_index do |image_url, i|
      stage_offset = i * 320
      thumb_offset = i/4 * 320 + i%4 * 60

      stage_scroll_view = ImageScrollView.alloc.initWithFrame([[stage_offset, 0], @stage.frame.size])
      stage_scroll_view.display_image(LOADING_IMAGE)

      thumb_image = UIImageView.alloc.initWithFrame([[thumb_offset+50, 5], [40, 40]]).tap do |thumb|
        thumb.contentMode = UIViewContentModeScaleAspectFit
        thumb.layer.borderColor = UIColor.orangeColor.CGColor
        thumb.image = LOADING_IMAGE
        thumb.whenTapped { select(i) }
      end

      @stage.addSubview(stage_scroll_view)
      @thumbnails.addSubview(thumb_image)

      @image_views << {
        url: image_url,
        view: stage_scroll_view,
        thumb: thumb_image
      }

      req = NSURLRequest.requestWithURL(image_url)
      opr = AFImageRequestOperation.imageRequestOperationWithRequest(req,
        imageProcessingBlock:lambda {|image| image },
        cacheName:nil,
        success:lambda {|req, res, image|
          NSOperationQueue.mainQueue.addOperationWithBlock(lambda {
            stage_scroll_view.display_image(image)
            thumb_image.image = image
          })
        },
        failure:lambda {|req, res, error|
          log_error error
          stage_scroll_view.display_image(ERROR_IMAGE)
          thumb_image.image = ERROR_IMAGE
        })
      @image_queue.addOperation(opr)
    end
    select(0)
  end
end