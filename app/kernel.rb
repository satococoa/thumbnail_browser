module Kernel
  def log_error(error)
    p error.code, error.domain, error.userInfo, error.localizedDescription
  end
end