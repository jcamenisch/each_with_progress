require 'erb'
require 'readline'
require 'forwardable'

class PicoProgress
  attr_reader :total, :out_io, :current, :template, :spinner_frames

  def self.spinner_frames
    @spinner_frames ||= %w[⠋ ⠙ ⠸ ⠴ ⠦ ⠇]
  end

  def self.spinner_frames=(frames)
    @spinner_frames = frames
  end

  TEMPLATES = {
    spinner: "<%= spinner %>",
    spinner_n: "<%= spinner %> <%= current %> complete...",
    spinner_n_out_of_t: "<%= spinner %> <%= current %> out of <%= total %> complete...",
    spinner_percent: "<%= spinner %> <%= percent %> complete%",
    spinner_n_percent: "<%= spinner %> <%= current %> (<%= percent %>%) complete...",
    spinner_n_out_of_t_percent: "<%= spinner %> <%= current %> out of <%= total %> (<%= percent %>%)...",
    n: "<%= current %> complete...",
    n_out_of_t: "<%= current %> out of <%= total %> complete...",
    percent: "<%= percent %>% complete...",
    n_percent: "<%= current %> (<%= percent %>%) complete...",
    n_out_of_t_percent: "<%= current %> out of <%= total %> (<%= percent %>%) complete...",
  }

  # Define a binding context for the ERB template. This will forward only the needed reader
  # methods back to the progress indicator without any unsafe (state-changing) methods.
  #
  # This assumes the template is untrusted since it can be user-provided.
  class PrintContext
    extend Forwardable

    def initialize(progress_indicator)
      @progress_indicator = progress_indicator
    end

    def_delegators :@progress_indicator, :total, :current, :max_width, :remaining, :percent, :spinner

    def get_binding
      binding
    end
  end

  def self.default_template
    @default_template || ENV['PROGRESS_INDICATOR_TEMPLATE'] || default_template_wo_total
  end

  def self.default_template=(template)
    @default_template = template_key(template)
  end

  def self.default_template_w_total
    @default_template_w_total || ENV['PROGRESS_INDICATOR_TEMPLATE_W_TOTAL'] || @default_template || :spinner_n_out_of_t_percent
  end

  def self.default_template_w_total=(template)
    @default_template_w_total = template_key(template)
  end

  def self.default_template_wo_total
    @default_template_wo_total || ENV['PROGRESS_INDICATOR_TEMPLATE_WO_TOTAL'] || :spinner_n
  end

  def self.default_template_wo_total=(template)
    @default_template_wo_total = template_key(template)
  end

  def self.template_key(template)
    template = template.to_sym

    if TEMPLATES.key?(template)
      template
    else
      raise "Unknown template: #{template}"
    end
  end

  def initialize(total: 0, out_io: $stdout)
    @total = total
    @out_io = out_io
    @current = 0
    @template = if total == 0
                  TEMPLATES[self.class.default_template_wo_total]
                else
                  TEMPLATES[self.class.default_template_w_total]
                end
    @spinner_frames = self.class.spinner_frames
    @print_context = PrintContext.new(self)
  end

  def max_width
    ::Readline.get_screen_size.last
  end

  def remaining
    total - current
  end

  def tick
    @current = current + 1
    print_progress
  end

  def reset(total: @total)
    @current = 0
    @total = total
  end

  def percent
    return 0 if total == 0

    (current.to_f / total * 100).round
  end

  def spinner
    spinner_frames[current % spinner_frames.length]
  end

  def print_progress
    # Move cursor up one line unless we’re just starting:
    move_up = current > 1 ? "\r\033[1A" : ''
    # Actual content of the frame:
    frame   = ERB.new(template).result(@print_context.get_binding)
    # Fill the terminal width with spaces to clear any extra characters from the previous frame:
    rpad    = ' ' * [max_width - frame.size, 0].max

    out_io.puts move_up + frame + rpad
  end
end

def PicoProgress(enum, **options)
  Enumerator.new do |yielder|
    total = options.delete(:total) || enum.count
    progress_indicator = PicoProgress.new(total: total, **options)

    enum.each do |item|
      yielder << item
      progress_indicator.tick
    end
  end
end
