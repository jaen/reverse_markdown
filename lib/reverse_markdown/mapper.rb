module ReverseMarkdown
  class Mapper
    attr_accessor :raise_errors
    attr_accessor :log_enabled, :log_level
    attr_accessor :li_counter
    attr_accessor :github_style_code_blocks
    attr_accessor :theaders
    attr_accessor :taligns

    def initialize(opts={})
      self.log_level   = :info
      self.log_enabled = true
      self.li_counter  = 0
      self.github_style_code_blocks = opts[:github_style_code_blocks] || false
      self.taligns = []
      self.theaders = 0      
    end

    def process_element(element)
      output = ''
      output << if element.text?
        process_text(element)
      else
        opening(element)
      end
      element.children.each do |child|
        output << process_element(child)
      end
      output << ending(element) unless element.text?
      output
    end

    private

    def opening(element)
      parent = element.parent ? element.parent.name.to_sym : nil
      case element.name.to_sym
        when :html, :body
          ""
        when :li
          indent = '    ' * [(element.ancestors('ol').count + element.ancestors('ul').count) - 1, 0].max
          if parent == :ol
            "#{indent}#{self.li_counter += 1}. "
          else
            "#{indent}- "
          end
        when :table
          "\n\n"
        when :thead # && 
          # binding.pry
          if parent == :table
            self.taligns = []
            self.theaders = 0
            '| '
          else
            ''
          end
        # when :tr
        #   self.trow = []
        # when :td, :th
        #   if self.trow == []
        #     trow << element.name.to_sym << sel
        when :tr
          if parent == :thead
            if (self.theaders += 1) > 1
              handle_error "malformed table header"
            end
            ''
          elsif parent == :tbody
            '| '
          end
        when :th
          self.taligns << (element['align'] || :left).to_sym
          ''
        when :pre
          "\r\n"
        when :ol
          self.li_counter = 0
          "\r\n"
        when :ul, :root#, :p
          "\r\n"
        when :p
          if element.ancestors.map(&:name).include?('blockquote')
            "\n\n> "
          elsif [nil, :body].include? parent
            is_first = true
            previous = element.previous
            while is_first == true and previous do
              is_first = false unless previous.content.strip == "" || previous.text?
              previous = previous.previous
            end
            is_first ? "" : "\n\n"
          else
            "\r\n"
          end
        when :h1, :h2, :h3, :h4 # /h(\d)/ for 1.9
          element.name =~ /h(\d)/
          '#' * $1.to_i + ' '
        when :em
          "*"
        when :strong
          "**"
        when :blockquote
          "> "
        when :code
          if parent == :pre
            language = parent["data-language"]
            self.github_style_code_blocks ? "\n~~~ #{language ? language : ""}\n" : "\n    "
          else
            " `"
          end
        when :a
          " ["
        when :img
          "!["
        when :hr
          "----------\n\n"
        else
          handle_error "unknown start tag: #{element.name.to_s}"
          ""
      end
    end

    def ending(element)
      parent = element.parent ? element.parent.name.to_sym : nil
      case element.name.to_sym
        when :html, :body, :pre, :hr #, :p
          ""
        when :th, :td
          ' |'
        when :tr
          "\n"
        when :table
          "\n"          
        when :thead
          if parent == :table
            (['|'].concat(self.taligns.map do |align|
              case align
                when :left
                  '---|'
                when :center
                  ':-:|'
                when :right
                  '--:|'
              end
            end) << "\n").join('')
          else
            ''
          end
        when :h1, :h2, :h3, :h4 # /h(\d)/ for 1.9
          "\r\n"
        when :em
          '*'
        when :strong
          '**'
        when :p
          "\r\n"
        when:li, :blockquote, :root, :ol, :ul
          "\r\n"
        when :code
          if parent == :pre
            self.github_style_code_blocks ? "\n```" : "\r\n"
          else
           '` '
          end
        when :a
          "](#{element.attribute('href').to_s}) "
        when :img
          if element.has_attribute?('alt')
            "#{element.attribute('alt')}](#{element.attribute('src')}) "
          else
            "#{element.attribute('src')}] "
          end
        else
          handle_error "unknown end tag: #{element.name}"
          ""
      end
    end

    def process_text(element)
      parent = element.parent ? element.parent.name.to_sym : nil
      case
        when parent == :code && !self.github_style_code_blocks
          element.text.strip.gsub(/\n/,"\n    ")
        else
          element.text.strip
      end
    end

    def handle_error(message)
      if raise_errors
        raise ReverseMarkdown::ParserError, message
      elsif log_enabled && defined?(Rails)
        Rails.logger.__send__(log_level, message)
      end
    end
  end
end
