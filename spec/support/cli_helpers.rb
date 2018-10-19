# frozen_string_literal: true

module CLIHelpers
  def capture_stdout
    begin
      stream = $stdout
      $stdout = StringIO.new
      yield
      result = $stdout.string
    ensure
      $stdout = stream
    end

    result
  end
end
