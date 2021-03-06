# Uncomment this if you reference any of your controllers in activate
#require_dependency 'application'

class PpWebsiteStandardExtension < Spree::Extension
  version "0.9.2"
  description "Describe your extension here"
  url "http://github.com/ashcrick/spree-pp-website-standard/tree/master"
  
  def activate

    # Add a partial for PaypalPayment txns
    Admin::OrdersController.class_eval do
      before_filter :add_pp_standard_txns, :only => :show
      def add_pp_standard_txns
        @txn_partials << 'pp_standard_txns'
      end
    end

    # Add a filter to the OrdersController so that if user is reaching us from an email link we can 
    # associate the order with the user (once they log in)
    OrdersController.class_eval do
      before_filter :associate_order, :only => :show
      private
      def associate_order  
        return unless payer_id = params[:payer_id]
        orders = Order.find(:all, :include => :paypal_payments, :conditions => ['payments.payer_id = ? AND orders.user_id is null', payer_id])
        orders.each do |order|
          order.update_attribute("user", current_user)
        end
      end
    end

    # add new events and states to the FSM
#    RAILS_DEFAULT_LOGGER.info(Order.state_machines.inspect)

    fsm = Order.state_machines['state']
    fsm.events["fail_payment"] = PluginAWeek::StateMachine::Event.new(fsm, "fail_payment")
    fsm.events["fail_payment"].transition(:to => 'payment_failure', :from => ['in_progress', 'payment_pending'])

    fsm.events["pend_payment"] = PluginAWeek::StateMachine::Event.new(fsm, "pend_payment")
    fsm.events["pend_payment"].transition(:to => 'payment_pending', :from => 'in_progress')
    fsm.after_transition :to => 'payment_pending', :do => lambda {|order| order.update_attribute(:completed_at, Time.now())}

    fsm.events["pay"].transition(:to => 'paid', :from => ['payment_pending', 'in_progress'])

    Order.class_eval do 
      has_many :paypal_payments
    end
  end
  
  def deactivate
    # admin.tabs.remove "Spree Pp Website Standard"
  end
  
end