class Admin
  class OrganizationsController < ApplicationController
    before_action :authenticate_admin!
    layout 'admin'

    include Taggable
    include Searchable

    def index
      @search_term = search_params(params)[:q]
      @all_orgs = search(policy_scope(Organization), @search_term, 1)
      @orgs = Kaminari.paginate_array(@all_orgs).page(params[:page])

      respond_to do |format|
        format.html
        format.json do
          render json: @orgs
        end
      end
    end

    def edit
      @organization = Organization.find(params[:id])
      @updated = @organization.updated_at

      authorize @organization
    end

    def update
      @organization = Organization.find(params[:id])

      authorize @organization
      preprocess_organization_params

      if @organization.update(org_params)
        redirect_to [:admin, @organization],
                    notice: 'Organization was successfully updated.'
      else
        render :edit
      end
    end

    def new
      @organization = Organization.new
      authorize @organization
    end

    def create
      preprocess_organization_params
      @organization = Organization.new(org_params)
      authorize @organization

      if @organization.save
        redirect_to admin_organizations_url,
                    notice: 'Organization was successfully created.'
      else
        render :new
      end
    end

    def destroy
      organization = Organization.find(params[:id])
      authorize organization
      organization.destroy
      redirect_to admin_organizations_url
    end

    private

    def preprocess_organization_params
      shift_and_split_params(params[:organization], :accreditations, :licenses)
    end

    def org_params
      params.require(:organization).permit(
        { accreditations: [] }, :alternate_name, :date_incorporated, :description,
        :email, { funding_sources: [] }, :legal_status, { licenses: [] }, :name,
        :tax_id, :tax_status, :website, { tag_list: [] },
        phones_attributes: %i[
          country_prefix department extension number number_type vanity_number id _destroy
        ]
      )
    end
  end
end
