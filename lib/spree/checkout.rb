def checkout_steps
  checkout_steps = %w{registration shipping shipping_method payment confirmation}
  checkout_steps.delete "registration" if current_user
  checkout_steps
end
