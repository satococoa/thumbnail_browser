class ThumbnailsController < UIViewController
  attr_accessor :url

  def loadView
    if super
      view.backgroundColor = UIColor.darkGrayColor
      close_button = UIButton.buttonWithType(UIButtonTypeRoundedRect).tap do |b|
        b.setTitle('閉じる', forState:UIControlStateNormal)
        b.frame = [[10, 374], [60, 30]]
        b.alpha = 0.8
        b.addTarget(self, action:'close', forControlEvents:UIControlEventTouchUpInside)
      end
      view.addSubview(close_button)
    end
    self
  end

  def viewWillAppear(animated)
    super
    # 画像のURLのみを抜き出す
    request = NSURLRequest.requestWithURL(@url)
    operation = AFHTTPRequestOperation.alloc.initWithRequest(request)
    operation.setCompletionBlockWithSuccess(
      lambda {|operation, response|
        str = operation.responseString
        error_ptr = Pointer.new(:object)
        parser = HTMLParser.alloc.initWithString(str, error:error_ptr)

        error = error_ptr[0]
        unless error.nil?
          p error.code, error.domain, error.userInfo, error.localizedDescription
          return
        end

        body = parser.body
        links = body.findChildTags('a')
        links.each do |link|
          url = NSURL.URLWithString(link.getAttributeNamed('href'))
          next if url.nil?
          next unless ['jpg', 'jpeg', 'png', 'gif'].include?(url.pathExtension)
          url = NSURL.URLWithString(url.path, relativeToURL:@url) if url.scheme !~ /^https?$/
          p "URL: #{url.absoluteString}"
        end
      },
      failure:lambda {|operation, error|
        p "Operation Error:"
        p error.code, error.domain, error.userInfo, error.localizedDescription
      })
    operation.start
  end

  def close
    self.dismissModalViewControllerAnimated(true)
  end

  def parserDidStartDocument(parser)
    p '===== parse Start! ====='
  end

  def parserDidEndDocument(parser)
    p '===== parse End! ====='
  end

  def parser(parser, didStartElement:elementName, namespaceURI:namespaceURI, qualifiedName:qName, attributes:attributeDict)
    p '===== parser:didStartElement... ====='
    p elementName, namespaceURI, qName, attributeDict
    p '===== // parser:didStartElement... ====='
  end

  def parser(parser, didEndElement:elementName, namespaceURI:namespaceURI, qualifiedName:qName)
    p '===== parser:didEndElement... ====='
    p elementName, namespaceURI, qName
    p '===== // parser:didEndElement... ====='
  end

  def parser(parser, foundCharacters:string)
    p '===== parser:foundCharacters ====='
    p string
    p '===== // parser:foundCharacters ====='
  end

  def parser(parser, parseErrorOccurred: parseError)
    p '===== parser:parseErrorOccurred ====='
    p parseError.code, parseError.domain, parseError.userInfo, parseError.localizedDescription
    p '===== // parse:parseErrorOccurred ====='
  end

end