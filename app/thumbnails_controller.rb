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
    parser = NSXMLParser.alloc.initWithContentsOfURL(@url)
    parser.delegate = self
    parser.parse

=begin
    request = NSURLRequest.requestWithURL(@url)
    operation = AFHTTPRequestOperation.alloc.initWithRequest(request)
    operation.setCompletionBlockWithSuccess(
      lambda {|operation, response|
        str = operation.responseString
        parser = NSXMLParser.alloc.initWithData(operation.responseData)
        parser.delegate = self
        parser.parse

        正規表現ではなくしたい
        images = str.scan(
          %r!\<a +href=(?:"|')?([^'"<>]+?\.(?:png|jpg|jpeg|gif))(?:"|')?.*?\>!m).to_a
        unless images.empty?
          images.each do |img|
            url = NSURL.URLWithString(img[0])
            url = NSURL.URLWithString(url.path, relativeToURL:@url) if url.scheme !~ /^https?$/
            p "URL: #{url.absoluteString}"
          end
        end
      },
      failure:lambda {|operation, error|
        p "Operation Error: #{error}"
      })
    operation.start
=end
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