class ImagesController < UIViewController
  include BW::KVO

  # 画像のURL(NSURL)の入った配列
  attr_accessor :image_urls, :current_page, :current_thumbnail_page

  LOADING_IMAGE = UIImage.imageNamed('loading.png')
  ERROR_IMAGE = UIImage.imageNamed('error.png')

  def loadView
    if super
      @image_queue = NSOperationQueue.new
      @current_page = 0
      @current_thumbnail_page = 0
      @visible_pages = []
      @recycled_pages = []

      view.backgroundColor = UIColor.darkGrayColor
    end
    self
  end

  def viewDidLoad
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

    observe(self, 'current_page') do |old_index, new_index|
      deselect(old_index) unless old_index.nil?
      load_page
    end

    observe(self, 'current_thumbnail_page') do |old_index, new_index|
      load_thumbnail_page
    end
  end

  def viewDidUnload
    unobserve_all
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
    @recycled_pages = []
  end

  def scrollViewDidEndDragging(scrollView, willDecelerate:decelerate)
    end_scroll unless decelerate
  end

  def scrollViewDidEndDecelerating(scrollView)
    end_scroll
  end

  def scrollViewDidEndScrollingAnimation(scrollView)
    # end_scroll
    # これが発生するときはscrollViewDidEndDeceleratingも発生しているので
    # ここでは呼ばなくてOK
  end

  private
  def end_scroll
    self.current_page = (@stage.contentOffset.x/320.0).ceil
    self.current_thumbnail_page = @current_page/4
  end

  def load_thumbnail_page
    @thumbnails.setContentOffset([@current_thumbnail_page*320, 0], animated:true)
  end

  def load_page
    # 不必要になったimage_scroll_viewを取り除く
    @visible_pages.each do |page|
      if page.index < @current_page - 1 || page.index > @current_page + 1
        page.removeFromSuperview
        @recycled_pages << page
      end
    end
    @visible_pages = @visible_pages - @recycled_pages

    # 現在のページ + 前後のページを表示する
    # ページがリサイクル出来ない場合は新しく作る
    (@current_page-1).upto(@current_page+1) do |index|
      next if index < 0 || index >= @pages_count

      unless page = @visible_pages.detect {|page| page.index == index}
        page_frame = [[index * 320, 0], @stage.frame.size]
        page =  @recycled_pages.pop.tap {|v| v.frame = page_frame unless v.nil? } || ImageScrollView.alloc.initWithFrame(page_frame)
        page.index = index
        @stage.addSubview(page)
        @visible_pages << page
        page.display_image(@images[index])
      end
    end

    # 選択状態にする
    @thumbs[@current_page].layer.borderWidth = 2
  end

  def deselect(index)
    # 1. 表示していた画像のズームを戻す
    if page = @visible_pages.detect {|page| page.index == index }
      page.zoomScale = page.minimumZoomScale
    end

    # 2. サムネイルの選択状態を解除
    @thumbs[index].layer.borderWidth = 0
  end

  def load_images
    @images = []
    @thumbs = []

    [@stage, @thumbnails].each do |container|
      container.subviews.each {|v| v.removeFromSuperview }
    end

    @pages_count = @image_urls.count

    @stage.contentSize = [320*@pages_count, 460]
    @thumbnails.contentSize = [320*(@pages_count/4.0).ceil, 40]

    @image_urls.each_with_index do |image_url, index|
      thumb_offset = index/4 * 320 + index%4 * 60
      thumb_image = UIImageView.alloc.initWithFrame([[thumb_offset+50, 5], [40, 40]]).tap do |thumb|
        thumb.contentMode = UIViewContentModeScaleAspectFit
        thumb.layer.borderColor = UIColor.orangeColor.CGColor
        thumb.image = LOADING_IMAGE
        thumb.whenTapped do
          @stage.setContentOffset([index*320, 0], animated:true)
          self.current_page = index
        end
      end

      @thumbnails.addSubview(thumb_image)

      @thumbs << thumb_image
      @images << LOADING_IMAGE

      req = NSURLRequest.requestWithURL(image_url)
      opr = AFImageRequestOperation.imageRequestOperationWithRequest(req,
        imageProcessingBlock:lambda {|image| image },
        cacheName:nil,
        success:lambda {|req, res, image|
          NSOperationQueue.mainQueue.addOperationWithBlock(lambda {
            @images[index] = image
            # 表示されているviewだけ画像を入れ替える
            @visible_pages.each do |page|
              page.display_image(image) if page.index == index
            end
            thumb_image.image = image
          })
        },
        failure:lambda {|req, res, error|
          log_error error
          NSOperationQueue.mainQueue.addOperationWithBlock(lambda {
            @images[index] = ERROR_IMAGE
            # 表示されているviewだけ画像を入れ替える
            @visible_pages.each do |page|
              page.display_image(ERROR_IMAGE) if page.index == index
            end
            thumb_image.image = ERROR_IMAGE
          })
        })
      @image_queue.addOperation(opr)
    end

    self.current_page = 0
  end
end