module ApplicationHelper
  def meta_title
    @meta_title ||= "#{app_name} | #{app_description}"
  end

  def meta_description
    @meta_description ||= app_description
  end

  def app_name
    "ecosyste.ms"
  end

  def app_description
    'Tools and datasets to support, sustain, and secure critical digital infrastructure.'
  end
end
