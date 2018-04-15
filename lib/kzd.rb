require "fileutils"
require "pstore"
require "psych"

module Kzd
  class Manager
    def initialize
      @pages = [] # [Kzd::Page instance, ...]
    end
    attr_accessor :pages

    def add_page(page)
      @pages << page
      self
    end

    def page_to_key(param)
      case param
      when Kzd::Page
        param.key
      when String
        param
      else
        raise
      end
    end

    def page_keys
      @pages.map {|page| page.key}
    end

    def prev_page(param)
      key = page_to_key(param)
      pos = page_keys.index(key)
      raise if pos.nil?
      return nil if pos == 0
      @pages[pos - 1]
    end

    def next_page(param)
      key = page_to_key(param)
      pos = page_keys.index(key)
      raise if pos.nil?
      return nil if pos == @pages.length - 1
      @pages[pos + 1]
    end

    def each_page
      @pages.each do |page|
        yield(page)
      end
    end

    def each_page_with_index
      @pages.each_with_index do |page, i|
        yield(page, i)
      end
    end

    def regs(param)
      param = param.first if Array === param
      key = page_to_key(param)
      pos = page_keys.index(key)
      return [] if pos.nil?
      @pages[pos].reg.strings
    end
  end

  class Page
    def initialize(param = {})
      raise if param.empty?
      @key = param[:key] || raise
      @filename_image = param[:img]
      @filename_xml = param[:xml] || param[:text]
      @reg = param[:pr]
      @lin = param[:ld]
    end
    attr_reader :key, :filename_image, :filename_xml
    attr_accessor :reg, :lin
    alias :filename_text :filename_xml
  end
end

require_relative "kzd/filenamehelper.rb"
require_relative "kzd/region.rb"
require_relative "kzd/regionprocessor.rb"
require_relative "kzd/line.rb"
require_relative "kzd/linemodifier.rb"
require_relative "kzd/linedetector.rb"
require_relative "kzd/reporter.rb"
