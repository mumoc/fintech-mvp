module Applications
  # Query object for listing applications: applies filters (country / status /
  # created_at range), eager-loads bank_record (no N+1 in serialization), orders
  # by recency, and paginates. Operates on the (Pundit-scoped) relation it is
  # given.
  class Search
    DEFAULT_PER_PAGE = 25
    MAX_PER_PAGE = 100

    Page = Data.define(:records, :page, :per_page, :total) do
      def total_pages
        per_page.zero? ? 0 : (total / per_page.to_f).ceil
      end
    end

    def self.call(scope:, filters: {}, page: nil, per_page: nil)
      new(scope: scope, filters: filters, page: page, per_page: per_page).call
    end

    def initialize(scope:, filters: {}, page: nil, per_page: nil)
      @scope = scope
      @filters = filters
      @page = [ page.to_i, 1 ].max
      @per_page = (per_page.presence&.to_i || DEFAULT_PER_PAGE).clamp(1, MAX_PER_PAGE)
    end

    def call
      relation = filtered.includes(:bank_record).order(created_at: :desc)
      total = relation.count
      records = relation.offset((@page - 1) * @per_page).limit(@per_page).to_a

      Page.new(records: records, page: @page, per_page: @per_page, total: total)
    end

    private

    def filtered
      relation = @scope
      relation = relation.where(country: @filters[:country]) if @filters[:country].present?
      relation = relation.where(status: @filters[:status]) if @filters[:status].present?
      relation = relation.where(created_at: from..) if from
      relation = relation.where(created_at: ..to) if to
      relation
    end

    def from = parse_time(@filters[:from])
    def to = parse_time(@filters[:to])

    def parse_time(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
