class SubscriptionsController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  before_action :redirect_unless_admin!, except: [:show, :index, :subscribe, :new, :create]
  before_action :redirect_unless_comm!, except: [:show, :subscribe, :new, :create]

  ANNUAL_SUBSCRIPTION_COST=1000

  def index
    @subscribers = Subscription.active.includes(:user).order(:name).group_by do |s|
      "#{s.name.downcase}"
    end.values.map(&:first)
  end

  def show
    @subscribers = Subscription.active.includes(:user).order(:name).group_by do |s|
      "#{s.name.downcase}"
    end.values.map(&:first)
  end

  def create
    # Amount in cents
    @amount = ANNUAL_SUBSCRIPTION_COST

    customer = Stripe::Customer.create(
      :email => params[:stripeEmail],
      :source  => params[:stripeToken]
    )

    charge = Stripe::Charge.create(
      :customer    => customer.id,
      :amount      => @amount,
      :description => 'Cuota de socio anual de la AMS',
      :currency    => 'eur'
    )

    current_user.add_subscription(
      charge.id,
      charge.amount,
    )

    NotificationMailer.with(user: current_user).notify_new_subscriber.deliver_now

  rescue Stripe::CardError => e
    flash[:error] = e.message
    redirect_to new_subscription_path
  end

  def destroy
    @subscription = Subscription.find(params[:id])
    @subscription.destroy
    flash[:success] = "Suscripción eliminada"
    redirect_to subscriptions_list_url
  end
end
