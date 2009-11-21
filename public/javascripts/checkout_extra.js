$(function() {
    var old_continue_section = continue_section;

    continue_section = function(section) {
        if (section == 'billing') {
            $('input#hidden_sstate').val($('input#hidden_bstate').val());
            $("#billing input, #billing select").each(function() {
                $("#shipping #"+ $(this).attr('id').replace('bill', 'shipment_attributes')).val($(this).val());
            })
            var result = old_continue_section(section);
            submit_shipping();
            return result;
        } else
            return old_continue_section(section);
    }

    var old_update_confirmation = update_confirmation

    update_confirmation = function(order) {
        var result = old_update_confirmation(order);
        var last_index = $('#last_index').val();
        $('#country').val($('#checkout_bill_address_attributes_country_id :selected').text());
        var shipping = "$0.00";
        for (var key in order.charges) {
            if (key != "Tax")
                shipping = order.charges[key];
        }
        $('#item_name_' + last_index).val("Delivery");
        $('#amount_' + last_index).val(shipping);
        $('#paypal_enter').show();
        return result;
    }
})