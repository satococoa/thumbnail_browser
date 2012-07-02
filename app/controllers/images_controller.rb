class ImagesController < UIViewController
  include BW::KVO

  # 画像のURL(NSURL)の入った配列
  attr_accessor :image_urls, :current_page, :current_thumbnail_page

  RECYCLE_BUFFER = 2
  LOADING_IMAGE = UIImage.imageNamed('loading.png')
  ERROR_IMAGE = UIImage.imageNamed('error.png')

  def loadView
    if super
      @image_queue = NSOperationQueue.new

      @current_page = 0
      @visible_pages = []
      @recycled_pages = []

      @current_thumbnail_page = 0
      @visible_thumbnail_pages = []
      @recycled_thumbnail_pages = []

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
      v.tag = 1

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
      v.delegate = self
      v.tag = 2
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
    @recycled_thumbnail_pages = []
  end

  def scrollViewDidEndDragging(scrollView, willDecelerate:decelerate)
    end_scroll(scrollView.tag) unless decelerate
  end

  def scrollViewDidEndDecelerating(scrollView)
    end_scroll(scrollView.tag)
  end

  def scrollViewDidEndScrollingAnimation(scrollView)
    # end_scroll
    # これが発生するときはscrollViewDidEndDeceleratingも発生しているので
    # ここでは呼ばなくてOK
  end

  def thumbnail_tapped(thumb, image_index)
    index = thumb.index*4 + image_index
    @stage.setContentOffset([index*320, 0], animated:true)
    self.current_page = index
    thumb.select_image(image_index)
  end

  private
  def end_scroll(tag)
    if tag == 1
      end_stage_scroll
    else
      end_thumbnail_scroll
    end
  end

  def end_stage_scroll
    self.current_page = (@stage.contentOffset.x/320.0).ceil
    self.current_thumbnail_page = @current_page/4
  end

  def end_thumbnail_scroll
    self.current_thumbnail_page = (@thumbnails.contentOffset.x/320.0).ceil
  end

  def load_page
    # 不必要になったimage_scroll_viewを取り除く
    @visible_pages.each do |page|
      if page.index < @current_page-RECYCLE_BUFFER || page.index > @current_page+RECYCLE_BUFFER
        page.removeFromSuperview
        @recycled_pages << page
      end
    end
    @visible_pages = @visible_pages - @recycled_pages

    # 現在のページ + 前後のページを表示する
    # ページがリサイクル出来ない場合は新しく作る
    (@current_page-RECYCLE_BUFFER).upto(@current_page+RECYCLE_BUFFER) do |index|
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

    # サムネイルの方もスクロールさせる
    @thumbnails.setContentOffset([@current_page/4*320, 0], animated:true)

    # 選択状態にする
    if thumb_page = @visible_thumbnail_pages.detect {|thumb_page| thumb_page.index == @current_page/4}
      thumb_page.select_image(@current_page%4)
    end
  end

  def load_thumbnail_page
    @visible_thumbnail_pages.each do |page|
      if page.index < @current_thumbnail_page-RECYCLE_BUFFER || page.index > @current_thumbnail_page + RECYCLE_BUFFER
        page.removeFromSuperview
        @recycled_thumbnail_pages << page
      end
    end
    @visible_thumbnail_pages = @visible_thumbnail_pages - @recycled_thumbnail_pages

    (@current_thumbnail_page-RECYCLE_BUFFER).upto(@current_thumbnail_page+RECYCLE_BUFFER) do |index|
      next if index < 0 || index >= (@pages_count / 4.0).ceil

      unless page = @visible_thumbnail_pages.detect {|page| page.index == index}
        page_frame = [[index * 320, 0], @thumbnails.frame.size]
        page =  @recycled_thumbnail_pages.pop.tap {|v| v.frame = page_frame unless v.nil? } || ThumbnailsView.alloc.initWithFrame(page_frame)
        page.index = index
        page.delegate = self
        @thumbnails.addSubview(page)
        @visible_thumbnail_pages << page
        page.display_images(@images[index*4, 4])
      end
    end
  end

  def deselect(index)
    # 1. 表示していた画像のズームを戻す
    if page = @visible_pages.detect {|page| page.index == index }
      page.zoomScale = page.minimumZoomScale
    end

    # 2. サムネイルの選択状態を解除
    if thumb_page = @visible_thumbnail_pages.detect {|thumb_page| thumb_page.index == index/4}
      thumb_page.deselect_image(index%4)
    end
  end

  def load_images
    [@stage, @thumbnails].each do |container|
      container.subviews.each {|v| v.removeFromSuperview }
    end

    @pages_count = @image_urls.count
    @stage.contentSize = [320*@pages_count, 460]
    @thumbnails.contentSize = [320*(@pages_count/4.0).ceil, 40]

    @images = []
    @image_urls.each_with_index do |image_url, index|
      # UIImageの配列
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
            @visible_thumbnail_pages.each do |thumb_page|
              image_index = index%4
              thumb_page.display_image(image, image_index) if thumb_page.index == index/4
            end
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
            @visible_thumbnail_pages.each do |thumb_page|
              image_index = index%4
              thumb_page.display_image(ERROR_IMAGE, image_index) if thumb_page.index == index/4
            end
          })
        })
      @image_queue.addOperation(opr)
    end

    self.current_page = 0
    self.current_thumbnail_page = 0
  end
end