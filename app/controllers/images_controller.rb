class ImagesController < UIViewController
  include BW::KVO

  # 画像のURL(NSURL)の入った配列
  attr_accessor :image_urls, :current_page, :current_thumbnail_page, :parent

  LOADING_IMAGE = UIImage.imageNamed('loading.png')
  ERROR_IMAGE = UIImage.imageNamed('error.png')

  RETRY_COUNT = 2
  RECYCLE_BUFFER = 2

  def loadView
    if super
      @image_queue = NSOperationQueue.new
      @processing = []

      @image_cache = NSCache.new.tap do |c|
        c.name = 'images'
        c.countLimit = 16
      end

      @current_page = 0
      @visible_pages = []

      @current_thumbnail_page = 0
      @visible_thumbnail_pages = []

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
      b.addTarget(self, action:'close', forControlEvents:UIControlEventTouchUpInside)
    end
    view.addSubview(@close_button)
  end

  def dealloc
    p "ImagesController dealloc #{self}"
    clear_cached_images
    super
  end

  def close
    @parent.close_images(self)
  end

  def toggle_hud(gesture)
    if @thumbnails.alpha > 0
      UIView.animateWithDuration(0.2,
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
    @processing = []
    AFNetworkActivityIndicatorManager.sharedManager.enabled = true

    observe(self, 'current_page') do |old_index, new_index|
      deselect(old_index) unless old_index.nil?
      load_page
    end

    observe(self, 'current_thumbnail_page') do |old_index, new_index|
      load_thumbnail_page
    end

    # サムネイルのタップ
    @thumbnail_tap_observer = NSNotificationCenter.defaultCenter.addObserverForName('ThumbnailTapped', object:nil, queue:NSOperationQueue.mainQueue, usingBlock:lambda {|notif|
      thumb = notif.object
      image_index = notif.userInfo[:image_index]
      index = thumb.index*4 + image_index
      @stage.setContentOffset([index*320, 0], animated:true)
      self.current_page = index
      thumb.select_image(image_index)
    })

    # 画像の取得完了
    @image_fetched_observer = NSNotificationCenter.defaultCenter.addObserver(self, selector:'image_fetched:', name:'ImageFetched', object:nil)

    setup_pages
  end

  def viewDidDisappear(animated)
    super
    @image_queue.cancelAllOperations
    unobserve_all
    [@thumbnail_tap_observer, @image_fetched_observer].each do |observer|
      NSNotificationCenter.defaultCenter.removeObserver(observer)
    end
    AFNetworkActivityIndicatorManager.sharedManager.enabled = false

    [@visible_pages, @visible_thumbnail_pages].each do |container|
      container.each do |page|
        page.removeFromSuperview
        # TODO: 一つ多めにretainしていることがあるため、ここでrelease
        # RubyMotionのバグ？
        if page.retainCount > 1
          p "!!!!!!!!!! Manually released #{page} !!!!!!!!!!"
          page.release
        end
      end
      container.clear
    end
    p "================ ImagesController#retainCount: #{self.retainCount} ================"
  end

  def didReceiveMemoryWarning
    p 'Memory Warning!! on ImagesController'
    @image_cache.removeAllObjects
    super
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

  private
  def setup_pages
    @pages_count = @image_urls.count
    @stage.contentSize = [320*@pages_count, 460]
    @thumbnails.contentSize = [320*(@pages_count/4.0).ceil, 40]

    # 一番左に戻す
    @stage.setContentOffset([0, 0], animated:false)
    @thumbnails.setContentOffset([0, 0], animated:false)

    self.current_page = 0
    self.current_thumbnail_page = 0
  end

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
    recycled_pages = []
    # 不必要になったimage_scroll_viewを取り除く
    @visible_pages.each do |page|
      if page.index < @current_page-RECYCLE_BUFFER || page.index > @current_page+RECYCLE_BUFFER
        recycled_pages << page
        page.removeFromSuperview
      end
    end
    @visible_pages.delete_if {|page| recycled_pages.include?(page)}

    # 現在のページ + 前後のページを表示する
    # ページがリサイクル出来ない場合は新しく作る
    (@current_page-RECYCLE_BUFFER).upto(@current_page+RECYCLE_BUFFER) do |index|
      next if index < 0 || index >= @pages_count

      unless @visible_pages.any? {|pg| pg.index == index}
        page_frame = [[index * 320, 0], @stage.frame.size]
        page = recycled_pages.pop.tap {|v|
          unless v.nil?
            v.frame = page_frame
            p v.retainCount
            v.send(:retain) # TODO: 手動でやる必要がある
          end
        } || ImageScrollView.alloc.initWithFrame(page_frame)
        @visible_pages << page
        # TODO: ここでなぜか先頭の要素のretainCountが減る
        # もっとも、減るほうが都合はいいのだが。
        page.index = index
        load_image_for_page(page, @image_urls[index])
        @stage.addSubview(page)
      end
    end

    # サムネイルの方もスクロールさせる
    @thumbnails.setContentOffset([@current_page/4*320, 0], animated:true)
  end

  def load_thumbnail_page
    recycled_thumbnail_pages = []
    @visible_thumbnail_pages.each do |page|
      if page.index < @current_thumbnail_page-RECYCLE_BUFFER || page.index > @current_thumbnail_page + RECYCLE_BUFFER
        recycled_thumbnail_pages << page
        page.removeFromSuperview
      end
    end
    @visible_thumbnail_pages.delete_if {|page| recycled_thumbnail_pages.include?(page)}

    (@current_thumbnail_page-RECYCLE_BUFFER).upto(@current_thumbnail_page+RECYCLE_BUFFER) do |index|
      next if index < 0 || index >= (@pages_count / 4.0).ceil

      unless @visible_thumbnail_pages.any? {|pg| pg.index == index}
        page_frame = [[index * 320, 0], @thumbnails.frame.size]
        page =  recycled_thumbnail_pages.pop.tap {|v|
          unless v.nil?
            v.frame = page_frame
            p v.retainCount
            v.send(:retain) # TODO: 手動でやる必要がある
          end
        } || ThumbnailsView.alloc.initWithFrame(page_frame)
        @visible_thumbnail_pages << page # TODO
        page.index = index
        load_images_for_thumbnails(page, @image_urls[index*4, 4])
        @thumbnails.addSubview(page)
      end
    end

    # 選択されている画像
    if thumb_page = @visible_thumbnail_pages.detect {|page| page.index == @current_page/4 }
      image_index = @current_page % 4
      thumb_page.select_image(image_index)
    end
  end

  def deselect(index)
    # 1. 表示していた画像のズームを戻す
    if page = @visible_pages.detect {|page| page.index == index }
      page.zoomScale = page.minimumZoomScale
    end

    # 2. サムネイルの選択状態を解除
    if thumb_page = @visible_thumbnail_pages.detect {|page| page.index == index/4}
      thumb_page.deselect_image(index%4)
    end
  end

  def load_image_for_page(page, url)
    page.display_image(LOADING_IMAGE)
    add_image_request_queue(page.index, url)
  end

  def load_images_for_thumbnails(thumbnails_view, urls)
    # まずはサムネイルを全部クリア
    thumbnails_view.remove_images

    # サムネイル画像を取得
    urls.each_with_index do |url, image_index|
      index = thumbnails_view.index * 4 + image_index
      thumbnails_view.display_image_with_index(LOADING_IMAGE, image_index)
      add_image_request_queue(index, url)
    end
  end

  def add_image_request_queue(index, url, retried = 0)
    # ファイル名としても使うのでMD5する
    key = key_for_url(url)
    if cached_image = cached_image_for_key(key)
      reload_image(cached_image, index)
    elsif !@processing.include?(key)
      @processing << key
      req = NSURLRequest.requestWithURL(url,
        cachePolicy:NSURLRequestReturnCacheDataElseLoad,
        timeoutInterval:60)
      opr = AFImageRequestOperation.imageRequestOperationWithRequest(req,
        imageProcessingBlock:lambda{|image| image},
        cacheName:nil,
        success:lambda {|req, res, image|
          @processing.delete key
          @image_cache.setObject(image, forKey:key)
          NSNotificationCenter.defaultCenter.postNotificationName('ImageFetched', object:image, userInfo:{index: index, key: key})
        },
        failure:lambda {|req, res, error|
          log_error error
          @processing.delete key
          # RETRY_COUNT分繰り返す
          if retried <= RETRY_COUNT
            App.run_after(1.0) { add_image_request_queue(index, url, retried + 1) }
          else
            @image_cache.setObject(ERROR_IMAGE, forKey:key)
            # エラーの画像を保存する必要は無い
            reload_image(ERROR_IMAGE, index)
          end
        })
      @image_queue.addOperation(opr)
    end
  end

  def cached_image_for_key(key)
    if cached_image = (@image_cache.objectForKey(key) || UIImage.imageWithContentsOfFile(cache_path_for_key(key)))
      cached_image
    else
      nil
    end
  end

  def key_for_url(url)
    NSData.MD5HexDigest(
      url.absoluteString.dataUsingEncoding(NSUTF8StringEncoding))
  end

  def file_manager
    NSFileManager.defaultManager
  end

  def cache_dir
    paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, true)
    paths[0]
  end

  def clear_cached_images
    images_dir = cache_dir.stringByAppendingPathComponent("images")
    err_ptr = Pointer.new(:object)
    file_manager.removeItemAtPath(images_dir, error:err_ptr)
    error = err_ptr[0]
    raise error if error
  end

  def cache_path_for_key(key)
    # 画像保存のディレクトリを作る
    # 数が多くなりそうなので分ける
    # 頭2文字をディレクトリ名とする
    path = cache_dir.stringByAppendingPathComponent("images/#{key[0, 2]}")
    unless file_manager.fileExistsAtPath(path)
      err_ptr = Pointer.new(:object)
      file_manager.createDirectoryAtPath(path, withIntermediateDirectories:true, attributes:nil, error:err_ptr)
      error = err_ptr[0]
      raise error if error
    end

    path.stringByAppendingPathComponent(key)
  end

  def image_fetched(notification)
    image = notification.object
    index = notification.userInfo[:index]
    key   = notification.userInfo[:key] # ファイル名としても使う

    # ファイルをローカルに保存
    # data = UIImagePNGRepresentation(image)
    data = UIImageJPEGRepresentation(image, 0.7)

    if file_manager.createFileAtPath(cache_path_for_key(key), contents:data, attributes:nil)
      reload_image(image, index)
    else
      # 保存に失敗
      p "Error saving image..."
      reload_image(ERROR_IMAGE, index)
    end
  end

  def reload_image(image, index)
    # @stageの画像更新
    if page = @visible_pages.detect {|page| page.index == index }
      page.display_image(image)
    end

    # @thumbnailsの画像更新
    if page = @visible_thumbnail_pages.detect {|page| page.index == index/4 }
      page.display_image_with_index(image, index%4)
      # サムネイルを選択状態に
      page.select_image(index%4) if @current_page == index
      page.setNeedsDisplay
    end
  end

end