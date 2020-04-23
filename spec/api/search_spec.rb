require 'rails_helper'

describe "GET 'search'" do
  context 'with valid keyword only' do
    before :all do
      @loc = create(:location)
      @nearby = create(:nearby_loc)
      @loc.update(updated_at: Time.zone.now - 1.day)
      @nearby.update(updated_at: Time.zone.now - 1.hour)
      LocationsIndex.reset!
    end

    before :each do
      get api_search_index_url(keyword: 'jobs', per_page: 1, subdomain: ENV['API_SUBDOMAIN'])
    end

    after(:all) do
      Organization.find_each(&:destroy)
    end

    it 'returns a successful status code' do
      expect(response).to be_successful
    end

    it 'is json' do
      expect(response.content_type).to eq('application/json')
    end

    it 'returns locations' do
      expect(json.first.keys).to include('coordinates')
    end

    it 'is a paginated resource', broken: true do
      get api_search_index_url(
        keyword: 'jobs', per_page: 1, page: 2, subdomain: ENV['API_SUBDOMAIN']
      )
      expect(json.length).to eq(1)
    end

    it 'returns an X-Total-Count header', broken: true do
      expect(response.status).to eq(200)
      expect(json.length).to eq(1)
      expect(headers['X-Total-Count']).to eq '2'
    end

    it 'sorts by updated_at when results have same full text search rank', broken: true do
      expect(json.first['name']).to eq @nearby.name
    end
  end

  describe 'specs that depend on :farmers_market_loc factory', broken: true do
    # We need to handle our new search logic based on location, coordinates, and radius.
    # Currently marking these specs as broken.

    before(:all) do
      create(:farmers_market_loc)
      LocationsIndex.reset!
    end

    after(:all) do
      Organization.find_each(&:destroy)
    end

    context 'with radius too small but within range' do
      it 'returns the farmers market name' do
        get api_search_index_url(
          location: 'la honda, ca', radius: 0.05, subdomain: ENV['API_SUBDOMAIN']
        )
        expect(json.first['name']).to eq('Belmont Farmers Market')
      end
    end

    context 'with radius too big but within range' do
      it 'returns the farmers market name' do
        get api_search_index_url(
          location: 'san gregorio, ca', radius: 50, subdomain: ENV['API_SUBDOMAIN']
        )
        expect(json.first['name']).to eq('Belmont Farmers Market')
      end
    end

    context 'with radius not within range' do
      it 'returns an empty response array' do
        get api_search_index_url(
          location: 'pescadero, ca', radius: 5, subdomain: ENV['API_SUBDOMAIN']
        )
        expect(json).to eq([])
      end
    end

    context 'with invalid zip' do
      it 'returns no results' do
        get api_search_index_url(location: '00000', subdomain: ENV['API_SUBDOMAIN'])
        expect(json.length).to eq 0
      end
    end

    context 'with invalid location' do
      it 'returns no results' do
        get api_search_index_url(location: '94403ab', subdomain: ENV['API_SUBDOMAIN'])
        expect(json.length).to eq 0
      end
    end
  end

  describe 'specs that depend on :location factory', broken: true do
    before(:all) do
      create(:location)
    end

    after(:all) do
      Organization.find_each(&:destroy)
    end

    context 'with invalid radius' do
      before :each do
        get api_search_index_url(location: '94403', radius: 'ads', subdomain: ENV['API_SUBDOMAIN'])
      end

      it 'returns a 400 status code' do
        expect(response.status).to eq(400)
      end

      it 'is json' do
        expect(response.content_type).to eq('application/json')
      end

      it 'includes an error description' do
        expect(json['description']).to eq('Radius must be a Float between 0.1 and 50.')
      end
    end

    context 'with invalid lat_lng parameter' do
      before :each do
        get api_search_index_url(lat_lng: '37.6856578-122.4138119', subdomain: ENV['API_SUBDOMAIN'])
      end

      it 'returns a 400 status code' do
        expect(response.status).to eq 400
      end

      it 'includes an error description' do
        expect(json['description']).
          to eq 'lat_lng must be a comma-delimited lat,long pair of floats.'
      end
    end

    context 'with invalid (non-numeric) lat_lng parameter' do
      before :each do
        get api_search_index_url(lat_lng: 'Apple,Pear', subdomain: ENV['API_SUBDOMAIN'])
      end

      it 'returns a 400 status code' do
        expect(response.status).to eq 400
      end

      it 'includes an error description' do
        expect(json['description']).
          to eq 'lat_lng must be a comma-delimited lat,long pair of floats.'
      end
    end

    context 'with plural version of keyword' do
      it "finds the plural occurrence in location's name field" do
        get api_search_index_url(keyword: 'services', subdomain: ENV['API_SUBDOMAIN'])
        expect(json.first['name']).to eq('VRS Services')
      end

      it "finds the plural occurrence in location's description field" do
        get api_search_index_url(keyword: 'jobs', subdomain: ENV['API_SUBDOMAIN'])
        expect(json.first['description']).to eq('Provides jobs training')
      end
    end

    context 'with singular version of keyword' do
      it "finds the plural occurrence in location's name field" do
        get api_search_index_url(keyword: 'service', subdomain: ENV['API_SUBDOMAIN'])
        expect(json.first['name']).to eq('VRS Services')
      end

      it "finds the plural occurrence in location's description field" do
        get api_search_index_url(keyword: 'job', subdomain: ENV['API_SUBDOMAIN'])
        expect(json.first['description']).to eq('Provides jobs training')
      end
    end
  end

  describe 'specs that depend on :location and :nearby_loc' do
    before(:all) do
      create(:location)
      create(:nearby_loc)
      LocationsIndex.reset!
    end

    after(:all) do
      Organization.find_each(&:destroy)
    end

    context 'when keyword only matches one location' do
      it 'only returns 1 result' do
        get api_search_index_url(keyword: 'library', subdomain: ENV['API_SUBDOMAIN'])
        expect(json.length).to eq(1)
      end
    end

    context "when keyword doesn't match anything" do
      it 'returns no results' do
        get api_search_index_url(keyword: 'blahab', subdomain: ENV['API_SUBDOMAIN'])
        expect(json.length).to eq(0)
      end
    end

    context 'with keyword and location parameters', broken: true do
      it 'only returns locations matching both parameters' do
        get api_search_index_url(
          keyword: 'books', location: 'Burlingame', subdomain: ENV['API_SUBDOMAIN']
        )
        expect(headers['X-Total-Count']).to eq '1'
        expect(json.first['name']).to eq('Library')
      end
    end

    context 'when keyword parameter has multiple words', broken: true do
      it 'only returns locations matching all words' do
        get api_search_index_url(keyword: 'library books jobs', subdomain: ENV['API_SUBDOMAIN'])
        expect(headers['X-Total-Count']).to eq '1'
        expect(json.first['name']).to eq('Library')
      end
    end
  end

  context 'lat_lng search', broken: true do
    it 'returns one result' do
      create(:location)
      create(:farmers_market_loc)
      get api_search_index_url(lat_lng: '37.583939,-122.3715745', subdomain: ENV['API_SUBDOMAIN'])
      expect(json.length).to eq 1
    end
  end

  context 'with singular version of keyword', broken: true do
    it 'finds the plural occurrence in organization name field' do
      # TODO: Need to handle singulr word search for keyword.
      create(:nearby_loc)
      get api_search_index_url(keyword: 'food stamp', subdomain: ENV['API_SUBDOMAIN'])
      expect(json.first['organization']['name']).to eq('Food Stamps')
    end

    it "finds the plural occurrence in service's keywords field", broken: true do
      # TODO: Need to handle singulr word search for keyword.
      create_service
      get api_search_index_url(keyword: 'pantry', subdomain: ENV['API_SUBDOMAIN'])
      expect(json.first['name']).to eq('VRS Services')
    end
  end

  context 'with plural version of keyword' do
    it 'finds the plural occurrence in organization name field', broken: true do
      # TODO: Need to handle plural word search for keyword.
      create(:nearby_loc)
      get api_search_index_url(keyword: 'food stamps', subdomain: ENV['API_SUBDOMAIN'])
      expect(json.first['organization']['name']).to eq('Food Stamps')
    end

    it "finds the plural occurrence in service's keywords field", broken: true do
      # TODO: Need to handle plural word search for keyword.
      create_service
      get api_search_index_url(keyword: 'emergencies', subdomain: ENV['API_SUBDOMAIN'])
      expect(json.first['name']).to eq('VRS Services')
    end
  end

  context 'when keyword matches category name' do
    before(:each) do
      create(:far_loc)
      create(:loc_with_nil_fields)
      cat = create(:category)
      create_service
      @service.category_ids = [cat.id]
      @service.save!
    end

    it 'boosts location whose services category name matches the query', broken: true do
      # TODO: Need to handle pagination in search logic.
      get api_search_index_url(keyword: 'food', subdomain: ENV['API_SUBDOMAIN'])
      expect(headers['X-Total-Count']).to eq '3'
      expect(json.first['name']).to eq 'VRS Services'
    end
  end

  context 'with org_name parameter' do
    before(:each) do
      create(:nearby_loc)
      create(:location)
      create(:soup_kitchen)
    end

    it 'returns results when org_name only contains one word that matches', broken: true do
      # TODO: Need to handle pagination in search logic.
      get api_search_index_url(org_name: 'stamps', subdomain: ENV['API_SUBDOMAIN'])
      expect(headers['X-Total-Count']).to eq '1'
      expect(json.first['name']).to eq('Library')
    end

    it 'only returns locations whose org name matches all terms', broken: true do
      # TODO: Need to handle pagination in search logic.
      get api_search_index_url(org_name: 'Food+Pantry', subdomain: ENV['API_SUBDOMAIN'])
      expect(headers['X-Total-Count']).to eq '1'
      expect(json.first['name']).to eq('Soup Kitchen')
    end

    it 'allows searching for both org_name and location', broken: true do
      # TODO: Need to handle pagination in search logic.
      get api_search_index_url(
        org_name: 'stamps',
        location: '1236 Broadway, Burlingame, CA 94010', subdomain: ENV['API_SUBDOMAIN']
      )
      expect(headers['X-Total-Count']).to eq '1'
      expect(json.first['name']).to eq('Library')
    end

    it 'allows searching for blank org_name and location', broken: true do
      # TODO: Need to handle serach logic for blank org_name and location.
      get api_search_index_url(org_name: '', location: '', subdomain: ENV['API_SUBDOMAIN'])
      expect(response.status).to eq 200
      expect(json.length).to eq(3)
    end
  end

  context 'when email parameter contains custom domain', broken: true do
    # TODO: Need to handle pagination and email logic in search logic.

    it "finds domain name when url contains 'www'" do
      create(:location, website: 'http://www.smchsa.org')
      create(:nearby_loc, email: 'info@cfa.org')
      get "#{api_search_index_url(subdomain: ENV['API_SUBDOMAIN'])}?email=foo@smchsa.org"
      expect(headers['X-Total-Count']).to eq '1'
    end

    it 'finds naked domain name' do
      create(:location, website: 'http://smchsa.com')
      create(:nearby_loc, email: 'hello@cfa.com')
      get "#{api_search_index_url(subdomain: ENV['API_SUBDOMAIN'])}?email=foo@smchsa.com"
      expect(headers['X-Total-Count']).to eq '1'
    end

    it 'finds long domain name in both url and email' do
      create(:location, website: 'http://smchsa.org')
      create(:nearby_loc, email: 'info@smchsa.org')
      get "#{api_search_index_url(subdomain: ENV['API_SUBDOMAIN'])}?email=foo@smchsa.org"
      expect(headers['X-Total-Count']).to eq '2'
    end

    it 'finds domain name when URL contains path' do
      create(:location, website: 'http://www.smchealth.org/mcah')
      create(:nearby_loc, email: 'org@mcah.org')
      get "#{api_search_index_url(subdomain: ENV['API_SUBDOMAIN'])}?email=foo@smchealth.org"
      expect(headers['X-Total-Count']).to eq '1'
    end

    it 'finds domain name when URL contains multiple paths' do
      create(:location, website: 'http://www.smchsa.org/portal/site/planning')
      create(:nearby_loc, email: 'sanmateo@ca.us')
      get "#{api_search_index_url(subdomain: ENV['API_SUBDOMAIN'])}?email=foo@smchsa.org"
      expect(headers['X-Total-Count']).to eq '1'
    end

    it 'finds domain name when URL contains a dash' do
      create(:location, website: 'http://www.bar-connect.ca.gov')
      create(:nearby_loc, email: 'gov@childsup-connect.gov')
      get "#{api_search_index_url(subdomain: ENV['API_SUBDOMAIN'])}?email=foo@bar-connect.ca.gov"
      expect(headers['X-Total-Count']).to eq '1'
    end

    it 'finds domain name when URL contains a number' do
      create(:location, website: 'http://www.prenatalto3.org')
      create(:nearby_loc, email: 'info@rwc2020.org')
      get "#{api_search_index_url(subdomain: ENV['API_SUBDOMAIN'])}?email=foo@prenatalto3.org"
      expect(headers['X-Total-Count']).to eq '1'
    end

    it 'returns locations where either email or admins fields match' do
      create(:location, email: 'moncef@smcgov.org')
      create(:location_with_admin)
      get api_search_index_url(email: 'moncef@smcgov.org', subdomain: ENV['API_SUBDOMAIN'])
      expect(headers['X-Total-Count']).to eq '2'
    end

    it 'does not return locations if email prefix is the only match' do
      create(:location, email: 'moncef@smcgov.org')
      create(:location_with_admin)
      get api_search_index_url(email: 'moncef@gmail.com', subdomain: ENV['API_SUBDOMAIN'])
      expect(headers['X-Total-Count']).to eq '0'
    end
  end

  context 'when email parameter contains generic domain', broken: true do
    # TODO: Need to handle search using email entity.

    it "doesn't return results for gmail domain" do
      create(:location, email: 'info@gmail.com')
      get "#{api_search_index_url(subdomain: ENV['API_SUBDOMAIN'])}?email=foo@gmail.com"
      expect(headers['X-Total-Count']).to eq '0'
    end

    it "doesn't return results for aol domain" do
      create(:location, email: 'info@aol.com')
      get "#{api_search_index_url(subdomain: ENV['API_SUBDOMAIN'])}?email=foo@aol.com"
      expect(headers['X-Total-Count']).to eq '0'
    end

    it "doesn't return results for hotmail domain" do
      create(:location, email: 'info@hotmail.com')
      get "#{api_search_index_url(subdomain: ENV['API_SUBDOMAIN'])}?email=foo@hotmail.com"
      expect(headers['X-Total-Count']).to eq '0'
    end

    it "doesn't return results for yahoo domain" do
      create(:location, email: 'info@yahoo.com')
      get "#{api_search_index_url(subdomain: ENV['API_SUBDOMAIN'])}?email=foo@yahoo.com"
      expect(headers['X-Total-Count']).to eq '0'
    end

    it "doesn't return results for sbcglobal domain" do
      create(:location, email: 'info@sbcglobal.net')
      get "#{api_search_index_url(subdomain: ENV['API_SUBDOMAIN'])}?email=foo@sbcglobal.net"
      expect(headers['X-Total-Count']).to eq '0'
    end

    it 'does not return locations if domain is the only match' do
      create(:location, email: 'moncef@gmail.com', admin_emails: ['moncef@gmail.com'])
      get api_search_index_url(email: 'foo@gmail.com', subdomain: ENV['API_SUBDOMAIN'])
      expect(headers['X-Total-Count']).to eq '0'
    end

    it 'returns results if admin email matches parameter' do
      create(:location, admin_emails: ['info@sbcglobal.net'])
      get "#{api_search_index_url(subdomain: ENV['API_SUBDOMAIN'])}?email=info@sbcglobal.net"
      expect(headers['X-Total-Count']).to eq '1'
    end

    it 'returns results if email matches parameter' do
      create(:location, email: 'info@sbcglobal.net')
      get "#{api_search_index_url(subdomain: ENV['API_SUBDOMAIN'])}?email=info@sbcglobal.net"
      expect(headers['X-Total-Count']).to eq '1'
    end
  end

  context 'when email parameter only contains generic domain name' do
    it "doesn't return results", broken: true do
      # TODO: Need to update email search logic.
      create(:location, email: 'info@gmail.com')
      get api_search_index_url(email: 'gmail.com', subdomain: ENV['API_SUBDOMAIN'])
      expect(headers['X-Total-Count']).to eq '0'
    end
  end

  describe 'sorting search results' do
    context 'sort when only location is present' do
      it 'sorts by distance by default', broken: true do
        # TODO: Need to update location search logic.
        create(:location)
        create(:nearby_loc)
        get api_search_index_url(
          location: '1236 Broadway, Burlingame, CA 94010', subdomain: ENV['API_SUBDOMAIN']
        )
        expect(json.first['name']).to eq('VRS Services')
      end
    end
  end

  context 'when location has missing fields' do
    it 'includes attributes with nil or empty values' do
      create(:loc_with_nil_fields)
      LocationsIndex.reset!
      get api_search_index_url(keyword: 'belmont', subdomain: ENV['API_SUBDOMAIN'])
      keys = json.first.keys
      %w[phones address].each do |key|
        expect(keys).to include(key)
      end
    end
  end

  context 'specs with misspelled search' do
    before(:all) do
      @loc1 = create(:location, name: "test")
    end

    it "should return correct location if we pass misspelled word 'covis-19'" do
      @loc1.update!(name: "covid-19 word location")
      LocationsIndex.reset!
      get api_search_index_url(keyword: 'covis-19')
      expect(json.first['name']).to eq('covid-19 word location')
    end

    it "should return correct location if we pass misspelled word 'acheive'" do
      @loc1.update!(description: "achieve word in description")
      LocationsIndex.reset!
      get api_search_index_url(keyword: 'acheive')
      expect(json.first['description']).to eq('achieve word in description')
    end

    it "should return correct location if we pass misspelled word 'seperate'" do
      organization = @loc1.organization
      organization.update!(name: "separate word in organization")
      LocationsIndex.reset!
      get api_search_index_url(keyword: 'seperate')
      expect(json.first['organization']['name']).to eq('separate word in organization')
    end
  end

end
