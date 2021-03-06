class LocationsSearch
  include ActiveData::Model

  PAGE = 1
  PER_PAGE = 30

  attribute :zipcode, type: String
  attribute :keywords, type: String
  attribute :org_name, type: String
  attribute :category_ids, type: Array
  attribute :tags, type: String
  attribute :page, type: String
  attribute :per_page, type: String

  def index
    LocationsIndex
  end

  def search
    search_results.page(fetch_page).per(fetch_per_page)
  end

  private

  def search_results
    # Order matters
    [
      organization_filter,
      tags_query,
      keyword_filter,
      zipcode_filter,
      category_filter,
      order
    ].compact.reduce(:merge)
  end

  def order
    index.order(
      featured_at: { missing: "_last", order: "asc" },
      covid19: { missing: "_last", order: "asc" },
      updated_at: { order: "desc" }
    )
  end

  def tags_query
    if tags?
      index.query(multi_match: {
                    query: tags,
                    fields: %w[tags],
                    analyzer: 'standard',
                    fuzziness: 'AUTO'
                  })
    end
  end

  def category_filter
    if category_ids?
      index.filter(
        terms: {
          category_ids: category_ids
        }
      )
    end
  end

  def zipcode_filter
    # NOTE: I think we also need to consider location's coordinates and its radius.
    # Because some of our specs are using these scenarios too.

    if zipcode?
      index.filter(match: {
                     zipcode: zipcode
                   })
    end
  end

  def keyword_filter
    if keywords?
      index.query(multi_match: {
                    query: keywords,
                    fields: %w[organization_name^3 name^2 description^1 keywords],
                    analyzer: 'standard',
                    fuzziness: 'AUTO'
                  })
    end
  end

  def organization_filter
    if org_name?
      index.filter(match_phrase: {
                     organization_name: org_name
                   })
    end
  end

  def fetch_page
    page.presence || PAGE
  end

  def fetch_per_page
    per_page.presence || PER_PAGE
  end
end
