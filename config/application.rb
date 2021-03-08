# frozen_string_literal: true

require 'active_record'
require 'active_support/core_ext/time'

ActiveRecord::Base.time_zone_aware_attributes = true
ActiveRecord::Base.default_timezone = :utc
Time.zone = 'Asia/Tokyo'

require_relative 'environment'
