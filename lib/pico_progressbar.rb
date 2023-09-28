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

  def self.template_w_total
    @template_w_total ||= "<%= spinner %> <%= current %> out of <%= total %> (<%= percent %>%)..."
  end

  def self.template_w_total=(template)
    @template_w_total = template
  end

  def self.template_wo_total
    @template_wo_total ||= "<%= spinner %> <%= current %>..."
  end

  def self.template_wo_total=(template)
    @template_wo_total = template
  end

  def initialize(total: 0, out_io: $stdout)
    @total = total
    @out_io = out_io
    @current = 0
    @template = if total.is_a?(Integer)
                  self.class.template_w_total
                else
                  self.class.template_wo_total
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
