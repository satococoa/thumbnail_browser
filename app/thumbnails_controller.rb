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

  def viewDidLoad
    p @url
  end

  def close
    self.dismissModalViewControllerAnimated(true)
  end

end