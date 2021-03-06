class OrdersController < ApplicationController
before_action :authenticate_user!

  include CurrentCart
  before_action :set_cart, only: [:new, :create]
  before_action :ensure_cart_isnt_empty, only: :new
  before_action :set_order, only: [:show, :edit, :update, :destroy]

  # GET /orders
  # GET /orders.json
  def index
    @orders = Order.where(user_id: current_user.id);
  end

  # GET /orders/1
  # GET /orders/1.json
  def show
  end

  # GET /orders/new
  def new
    @order = Order.new
  end

  # GET /orders/1/edit
  def edit
  end

  # POST /orders
  # POST /orders.json

  def create
    @orders = Order.all
    @order = Order.new(order_params)
    @order.add_line_items_from_cart(@cart)
    @order.user_id = current_user.id
    @order.save
    
    print "@@@@@@@@@@@@@@@@@@@@@ order.user IS : #{current_user.id}"
    
    # make an if statement here to check 
    # if pay with was chosen credit card
    if order_params[:pay_type] == "Credit Card"
      Stripe.api_key = "sk_test_d89xcUW01GrxnzMMyPtdQwUQ"
            
      print  "print out the total price #{@cart.total_price}"
      
      token = params[:stripeToken]
      number = 100 * @cart.total_price
      stripePrice = number.floor
      charge = Stripe::Charge.create({
          source: token,
          amount: stripePrice,
          currency: 'usd',
          description: 'Example charge'
      })
    end

    respond_to do |format|
      if @order.save
        # This is to send an email with sidekiq
        ReportWorker.perform_async(@order.id)

        Cart.destroy(session[:cart_id])

        session[:cart_id] = nil
        # slow controller Pago
        # ChargeOrderJob.perform_later(@order,pay_type_params.to_h)
        format.html { redirect_to store_index_url(locale: I18n.locale), 
            notice: I18n.t('.thanks')}
        format.json {render :show, statu: :created, 
        locations: @order}
      else
        format.html { render :new}
        format.json { render json: @order.errors,
          status: :unprocessable_entity} 
      end
    end
    
  end

  # PATCH/PUT /orders/1
  # PATCH/PUT /orders/1.json
  def update
    respond_to do |format|
      if @order.update(order_params)
        format.html { redirect_to @order, notice: 'Order was successfully updated.' }
        format.json { render :show, status: :ok, location: @order }
      else
        format.html { render :edit }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end
  # Pay type params
  def pay_type_params
    # if order_params[:pay_type] == "Credit Card"
      # params.require(:order).permit(:credit_card_number, :expiration_date)
      
    if order_params[:pay_type] == "Check"
      params.require(:order).permit(:routing_number, :account_number)
    elsif order_params[:pay_type] == "Purchase order"
      params.require(:order).permit(:po_number)
    else
      {}
    end
  end


  # DELETE /orders/1
  # DELETE /orders/1.json
  def destroy
    @order.destroy
    respond_to do |format|
      format.html { redirect_to orders_url, notice: 'Order was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def who_bought 
    @product = Product.find(params[:id])
    @latest_order = @product.orders.order(:updated_at).last
    if stale?(@latest_order)
      respond_to do |format|
        format.atom
      end
    end
  end



  
  private 
    def ensure_cart_isnt_empty
      if @cart.line_items.empty?
        redirect_to store_index_url, notice: 'Your cart is empty'
      end
    end
  
    
    # Use callbacks to share common setup or constraints between actions.
    def set_order
      @order = Order.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def order_params
      params.require(:order).permit(:name, :address, :text, :email, :pay_type)
    end
end
