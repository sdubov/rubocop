# encoding: utf-8

require 'open3'

# The reincarnation of syntax cop :)
module MRISyntaxChecker
  module_function

  def offences_for_source(source, fake_cop_name = 'Syntax', grep_message = nil)
    if source.is_a?(Array)
      source_lines = source
      source = source_lines.join("\n")
    else
      source_lines = source.each_line.to_a
    end

    offences = []

    check_syntax(source).each_line do |line|
      line_number, severity, message = process_line(line)
      next unless line_number
      next if grep_message && !message.include?(grep_message)
      offences << Rubocop::Cop::Offence.new(
        severity,
        Rubocop::Cop::Location.new(line_number, 0, source_lines),
        message.capitalize,
        fake_cop_name
      )
    end

    offences
  end

  def check_syntax(source)
    fail 'Must be running with MRI' unless RUBY_ENGINE == 'ruby'

    stdin, stderr, thread = nil

    # It's extremely important to run the syntax check in a
    # clean environment - otherwise it will be extremely slow.
    if defined? Bundler
      Bundler.with_clean_env do
        stdin, _, stderr, thread = Open3.popen3('ruby', '-cw')
      end
    else
      stdin, _, stderr, thread = Open3.popen3('ruby', '-cw')
    end

    stdin.write(source)
    stdin.close
    thread.join

    stderr.read
  end

  def process_line(line)
    match_data = line.match(/.+:(\d+): (warning: )?(.+)/)
    return nil unless match_data
    line_number, warning, message = match_data.captures
    severity = warning ? :warning : :error
    [line_number.to_i, severity, message]
  end
end