# frozen_string_literal: true

module TakemaroBlog
end

module TakemaroBlog::ResponseHelper
  def get_value(key)
    if params.key? key then { value: params[key] } else {} end
  end

  def formats
    { 'haml' => 'HAML', 'html' => 'HTML', 'markdown' => 'Markdown', 'erb' => 'ERB' }
  end

  def script
    require 'json'
    haml :script, layout: false
  end

  def script?
    !!@html
  end
end
