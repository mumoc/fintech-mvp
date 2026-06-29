# Result pattern: services return a success or failure object instead of using
# exceptions for control flow. Failures carry a machine-readable `code` and
# human-readable `messages`.
class Result
  Error = Data.define(:code, :messages)

  attr_reader :value, :error

  def self.success(value = nil)
    new(success: true, value: value)
  end

  def self.failure(code, messages = [])
    new(success: false, error: Error.new(code: code, messages: Array(messages)))
  end

  def initialize(success:, value: nil, error: nil)
    @success = success
    @value = value
    @error = error
  end

  def success? = @success
  def failure? = !@success
end
