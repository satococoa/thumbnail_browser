class Document
  def initialize(html_str)
    error_ptr = Pointer.new(:object)
    @doc = GDataXMLDocument.alloc.initWithHTMLString(html_str,
      options:0, error:error_ptr)
    error = error_ptr[0]
    raise error unless error.nil?
  end

  def image_urls
    xpath = "//a[contains(@href, '.jpg') or contains(@href, '.jpeg') or contains(@href, '.png') or contains(@href, '.gif')]/@href"

    error_ptr = Pointer.new(:object)
    links = @doc.nodesForXPath(xpath, error:error_ptr)
    error = error_ptr[0]
    raise error unless error.nil?

    urls = links.map.each_with_object([]) {|link, ary|
      url = NSURL.URLWithString(link.stringValue)
      url = NSURL.URLWithString(url.path, relativeToURL:@url) if url.scheme !~ /^https?$/
      ary << url
    }
  end
end