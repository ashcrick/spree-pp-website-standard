class PaypalPaymentsController < Spree::BaseController
  include ActiveMerchant::Billing::Integrations
  skip_before_filter :verify_authenticity_token      
  before_filter :load_object, :only => :successful
  layout 'application'
  
  resource_controller
  belongs_to :order

  # NOTE: The Paypal Instant Payment Notification (IPN) results in the creation of a PaypalPayment
  create.after do
    # mark the checkout process as complete (even if the ipn results in a failure - no point in letting the user 
    # edit the order now)
    object.update_attribute("email", params[:payer_email])
    if RAILS_ENV == 'development'
      uri = URI.parse(Spree::Paypal::Config[:sandbox_url])
    else
      uri = URI.parse(Spree::Paypal::Config[:paypal_url])
    end
    raw_post = request.raw_post
    http = Net::HTTP.new(uri.host, 443)
    http.use_ssl = true
    verified = http.get(uri.path + '?cmd=_notify-validate&' + request.raw_post)
    success = (verified.body == 'VERIFIED')
    RAILS_DEFAULT_LOGGER.info 'PayPal Call:' + verified.body
    RAILS_DEFAULT_LOGGER.info 'Success:' + success.to_s

    ipn = Paypal::Notification.new(request.raw_post)

    # create a transaction which records the details of the notification
    txn = object.txns.find_by_transaction_id(ipn.transaction_id)
    object.txns.create(:transaction_id => ipn.transaction_id,
                       :amount => ipn.gross, 
                       :fee => ipn.fee,
                       :currency_type => ipn.currency, 
                       :status => ipn.status, 
                       :received_at => ipn.received_at) if !txn

    if (@order.state != "paid") and success
      case ipn.status
      when "Completed"
        if ipn.gross.to_d == @order.total
          @order.pay!
        else
          @order.fail_payment!
          logger.error("Incorrect order total during Paypal's notification, please investigate (Paypal processed #{ipn.gross}, and order total is #{@order.total})")
        end
      when "Pending"
        @order.fail_payment!
        logger.info("Received an unexpected pending status for order: #{@order.number}")
      else
        @order.fail_payment!
        logger.info("Received an unexpected status for order: #{@order.number}")
      end
    end
  end

  create.response do |wants|
    wants.html do 
      render :nothing => true    
    end
  end

  # Action for handling the "return to site" link after user completes the transaction on the Paypal website.  
  def successful
    @order.checkout.update_attributes(:ip_address => request.env['REMOTE_ADDR'] || "unknown", :email => params[:payer_email])
    # its possible that the IPN has already been received at this point so that
    if @order.paypal_payments.empty?
      # create a payment and record the successful transaction
#      paypal_payment = @order.paypal_payments.create(:email => params[:payer_email], :payer_id => params[:payer_id])
#      paypal_payment.txns.create(:amount => params[:mc_gross].to_d,
#                                 :status => params[:payment_status],
#                                 :transaction_id => params[:txn_id],
#                                 :fee => params[:payment_fee],
#                                 :currency_type => params[:mc_currency],
#                                 :received_at => params[:payment_date])
      # advance the state
      @order.pend_payment!  
    else
      paypal_payment = @order.paypal_payments.last
    end
    
    # remove order from the session (its not really practical to allow the user to edit the session anymore)
    session[:order_id] = nil
    
    if current_user
      @order.update_attribute("user", current_user)
      redirect_to order_url(@order) and return
    else
      flash[:notice] = "Please create an account or login so we can associate this order with an account"
      session[:return_to] = "#{order_url(@order)}?payer_id=#{paypal_payment.payer_id}"
      redirect_to signup_path
    end
  end

  def startup
    
  end
end