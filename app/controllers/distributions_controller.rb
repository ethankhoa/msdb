class DistributionsController < ApplicationController
  def index
  end

  def new
    @client            = Client.find(params[:client_id])
    @distribution      = Distribution.new
    @distribution_item = DistributionItem.new
  end

  def create
    client       = Client.find(params[:client_id])
    household    = client.household
    distribution = Distribution.new(:household_id => household.id,
                                    :cid => params[:cid],
                                    :distribution_items_attributes => params[:transaction_items_attributes])

    if distribution.save
      flash[:confirm]= "Checkout completed for #{client.first_last_name}"
      redirect_to distributions_path
    else
      messages = ['A problem prevented the distribution from being saved.']
      messages += distribution.errors.full_messages
      messages.join('<br/>')
      render :json => {:error => messages}, :status => :ok
    end
  end

  def update
  end
end
