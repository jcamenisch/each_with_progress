require 'minitest/autorun'
require 'minitest/spec'
require 'pico_progressbar'
require 'debug'

describe PicoProgress do
  let(:out_io) { StringIO.new }

  describe 'when given a finite range' do
    let(:subject) { PicoProgress(1..10, out_io: out_io) }

    it 'prints a progress bar frame for every element' do
      subject.each do |i|
        # noop
      end

      _(out_io.string).must_equal <<-EOS
⠙ 1 out of 10 (10%)
\r\e[1A⠸ 2 out of 10 (20%)
\r\e[1A⠴ 3 out of 10 (30%)
\r\e[1A⠦ 4 out of 10 (40%)
\r\e[1A⠇ 5 out of 10 (50%)
\r\e[1A⠋ 6 out of 10 (60%)
\r\e[1A⠙ 7 out of 10 (70%)
\r\e[1A⠸ 8 out of 10 (80%)
\r\e[1A⠴ 9 out of 10 (90%)
\r\e[1A✓ 10 out of 10 (100%)
      EOS
    end
  end

  describe 'when given an endless range' do
    let(:subject) { PicoProgress(1.., out_io: out_io) }

    it 'prints a progress bar frame for every iteration step' do
      subject.take(11).each do |i|
        # noop
      end

      _(out_io.string).must_equal <<-EOS
⠙ 1
\r\e[1A⠸ 2
\r\e[1A⠴ 3
\r\e[1A⠦ 4
\r\e[1A⠇ 5
\r\e[1A⠋ 6
\r\e[1A⠙ 7
\r\e[1A⠸ 8
\r\e[1A⠴ 9
\r\e[1A⠦ 10
      EOS
    end
  end
end
