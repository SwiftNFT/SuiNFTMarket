module swift_market::err_code {

    const Prefix: u64=0x0000;
    //market  errcode
    public  fun not_auth_operator(): u64{
        Prefix+0001
    }

    public fun err_input_amount(): u64{
        Prefix+0002
    }

    public  fun  err_amount_is_zero(): u64{
        Prefix+0003
    }






}
