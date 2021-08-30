module NoticesHelper
  DEFAULT_VARIANT = :notice
  VARIANT_TYPES = {
    DEFAULT_VARIANT => "",
    :alert => "flash-warn",
    :error => "flash-error",
    :success => "flash-success"
  }.freeze

  def notice_variant(type = DEFAULT_VARIANT)
    if type
      VARIANT_TYPES[type.to_sym]
    else
      ""
    end
  end
end
