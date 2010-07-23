# encoding: utf-8
# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class RussianAdaptationExtension < Spree::Extension
  version "0.2"
  description "Adapts Spree to the Russian reality."
  url "http://github.com/romul/spree-russian-adaptation"

  # Please use russian_adaptation/config/routes.rb instead for extension routes.

  def self.require_gems(config)
    config.gem 'russian', :lib => 'russian', :source => 'http://gemcutter.org'
    config.gem 'prawn'
  end

  def activate
    
    Time::DATE_FORMATS[:date_time24] = "%d.%m.%Y - %H:%M"
    Time::DATE_FORMATS[:short_date] = "%d.%m.%Y"
    
    require "active_merchant/billing/gateways/robo_kassa"
    Gateway::RoboKassa.register
    
    [ Calculator::RussianPost ].each(&:register) 
    

    # replace .to_url method provided by stringx gem by .parameterize provided by russian gem
    String.class_eval do
      def to_url
        self.parameterize
      end
    end


    OrdersController.class_eval do
      def sberbank_billing
        if (@order.shipping_method.name =~ /предопл/ && can_access?)
          render :layout => false
        else
          flash[:notice] = 'Счёт не найден.'
          redirect_to root_path
        end
      end     
    end

    CheckoutsController.class_eval do
      
      # def complete_checkout
      #   complete_order
      #   order_params = {:checkout_complete => true}
      #   session[:order_id] = nil
      #   flash[:commerce_tracking] = I18n.t("notice_messages.track_me_in_GA")
      #   redirect_url = (@checkout.payment && @checkout.payment.payment_method.type == 'Gateway::RoboKassa') ? 
      #     @order.checkout.payment.payment_method.robokassa_payment_url({:invoice => @order.number[1..-1], :summa =>  @order.total, :value => "Оплатить"},{:shpa => "omed"} ) :
      #     order_url(@order, {:checkout_complete => true, :order_token => @order.token})
      #   redirect_to redirect_url
      # end

    end

    Gateway.class_eval do
      def self.current
        self.first :conditions => ["environment = ? AND active = ?", RAILS_ENV, true]
      end
    end

    Checkout.class_eval do
      validation_group :address, :fields=> [
                                            "ship_address.firstname", "ship_address.lastname", "ship_address.phone", 
                                            "ship_address.zipcode", "ship_address.state", "ship_address.lastname", 
                                            "ship_address.address1", "ship_address.city", "ship_address.statename", 
                                            "ship_address.zipcode", "ship_address.secondname"]
      
      def bill_address
        ship_address || Address.default
      end
    end
    
    # state_machine :initial => 'address' do
    #   after_transition :to => 'complete', :do => :complete_order
    #   before_transition :to => 'complete', :do => :process_payment
    #   event :next do
    #     transition :to => 'delivery', :from  => 'address'
    #     transition :to => 'payment', :from => 'delivery'
    #     transition :to => 'confirm', :from => 'payment', :if => Proc.new { Gateway.current and Gateway.current.payment_profiles_supported? }
    #     transition :to => 'complete', :from => 'confirm'
    #     transition :to => 'complete', :from => 'payment'
    #   end
    # end

    ActionView::Helpers::NumberHelper.module_eval do
      def number_to_currency(number, options = {})
        rub = number.to_i
        kop = ((number - rub)*100).round.to_i
        if (kop > 0)
          "#{rub}&nbsp;#{RUSSIAN_CONFIG['country']['currency']}&nbsp;#{'%.2d' % kop}&nbsp;коп.".mb_chars
        else
          "#{rub}&nbsp;#{RUSSIAN_CONFIG['country']['currency']}".mb_chars
        end
      end
    end
    
    Admin::BaseHelper.module_eval do 
      def text_area(object_name, method, options = {})
        begin
          ckeditor_textarea(object_name, method, :width => '100%', :height => '350px')
        rescue
          super
        end
      end      
    end

    Admin::OrdersController.class_eval do
      show.success.wants.pdf { render :layout => false, :template => 'admin/orders/show.pdf.prawn'}
    end

    OrdersHelper.module_eval do
      def russian_post_tracking_url bar_code
        "http://info.russianpost.ru/servlet/post_item?action=search&searchType=barCode&barCode=#{bar_code}"
      end 

      def russian_post_delivery_status_url bar_code
        if bar_code
          link_to t(:order_delivery_status), russian_post_tracking_url(bar_code), {:target => :blank, :title => t(:order_delivery_status_according_to_russian_post)}
        else
          ''
        end
      end
    end

    AppConfiguration.class_eval do
      preference :print_invoice_logo_path, :string, :default => '/images/admin/bg/spree_50.png'
    end

  end
end

