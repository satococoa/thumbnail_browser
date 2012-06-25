class ThumbnailsController < UIViewController
  attr_accessor :url

  def loadView
    if super
      view.backgroundColor = UIColor.whiteColor
    end
    self
  end

  def viewDidLoad
    p @url
  end

end