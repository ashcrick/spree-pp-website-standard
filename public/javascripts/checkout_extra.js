$(function() { 
    $('#continue_billing').click(function() {
        $('input#hidden_sstate').val($('input#hidden_bstate').val());
        $("#billing input, #billing select").each(function() {
            $("#shipping #"+ $(this).attr('id').replace('bill', 'shipment_attributes')).val($(this).val());
        })
        submit_shipping();
    })

//    $('#continue_confirmation').click(function() {
//        $('input#hidden_sstate').val($('input#hidden_bstate').val());
//        $("#billing input, #billing select").each(function() {
//            $("#shipping #"+ $(this).attr('id').replace('bill', 'shipment_attributes')).val($(this).val());
//        })
//        submit_shipping();
//        return false;
//    })

})