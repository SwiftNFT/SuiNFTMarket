module swift_market::ob_market {
    use liquidity_layer_v1::orderbook;
    use liquidity_layer_v1::orderbook::Orderbook;
    use sui::kiosk::Kiosk;
    use sui::object::{ID, UID};
    use sui::tx_context::{TxContext, sender};
    use ob_allowlist::allowlist::Allowlist;
    use nft_protocol::royalty_strategy_bps::BpsRoyaltyStrategy;
    use sui::transfer_policy::TransferPolicy;
    use sui::coin::Coin;
    use sui::coin;
    use nft_protocol::transfer_allowlist;
    use sui::transfer::{public_transfer, share_object};
    use nft_protocol::royalty_strategy_bps;
    use ob_request::transfer_request;
    use sui::object;


    const EAmountOfMoney: u64 = 0;
    const EMarketFee: u64 = 1;


    ///Record some important information of the market
    struct ObMarketplace has key {
        id: UID,
        ///marketplace fee collected by marketplace
        beneficiary: address,
        ///marketplace fee  of the marketplace
        fee: u64,
    }

    fun init(ctx: &mut TxContext){
        let ob_market = ObMarketplace {
            id: object::new(ctx),
            beneficiary: sender(ctx),
            fee: 0,
        };
        share_object(ob_market)
    }

    public entry fun modify_ob_market(ob_market: &mut ObMarketplace, beneficiary: address, fee: u64) {
        assert!(fee < 10000, EMarketFee);
        ob_market.fee = fee;
        ob_market.beneficiary = beneficiary
    }

    public entry fun ob_list<Item: key+store, CoinType>(
        ob_market: &ObMarketplace,
        book: &mut Orderbook<Item, CoinType>,
        seller_kiosk: &mut Kiosk,
        price: u64,
        nft_id: ID,
        ctx: &mut TxContext
    ){
        let market_fee = price * ob_market.fee / 10000;
        orderbook::create_ask_with_commission(book, seller_kiosk, price, nft_id, ob_market.beneficiary, market_fee, ctx);
    }

    public entry fun ob_adjust_price<Item: key+store, CoinType>(
        book: &mut Orderbook<Item, CoinType>,
        seller_kiosk: &mut Kiosk,
        older_price: u64,
        nft_id: ID,
        new_price: u64,
        ctx: &mut TxContext){
        orderbook::edit_ask(book, seller_kiosk, older_price, nft_id, new_price, ctx);
    }

    public entry fun ob_delist<Item: key+store, CoinType>(
        book: &mut Orderbook<Item, CoinType>,
        seller_kiosk: &mut Kiosk,
        price: u64,
        nft_id: ID,
        ctx: &mut TxContext){
        orderbook::cancel_ask(book, seller_kiosk, price, nft_id, ctx);
    }

    public entry fun ob_buy<Item: key+store, CoinType>(
        ob_market: &ObMarketplace,
        book: &mut Orderbook<Item, CoinType>,
        allow_list: &Allowlist,
        royalty_strategy: &mut BpsRoyaltyStrategy<Item>,
        transfer_policy: &mut TransferPolicy<Item>,
        seller_kiosk: &mut Kiosk,
        buyer_kiosk: &mut Kiosk,
        nft_id: ID,
        price: u64,
        wallet: &mut Coin<CoinType>,
        ctx: &mut TxContext
    ){
        let market_fee = price * ob_market.fee / 10000;
        assert!(coin::value(wallet) == market_fee + price, EAmountOfMoney);
        let market_coin = coin::split(wallet, market_fee, ctx);
        public_transfer(market_coin, ob_market.beneficiary);
        let ob_transfer_request = orderbook::buy_nft<Item, CoinType>(book, seller_kiosk, buyer_kiosk, nft_id, price, wallet, ctx);
        transfer_allowlist::confirm_transfer(allow_list, &mut ob_transfer_request);
        royalty_strategy_bps::confirm_transfer<Item, CoinType>(royalty_strategy, &mut ob_transfer_request);
        transfer_request::confirm<Item, CoinType>(ob_transfer_request, transfer_policy, ctx);
    }

    public entry fun ob_buy_without_allow_list<Item: key+store, CoinType>(
        ob_market: &ObMarketplace,
        book: &mut Orderbook<Item, CoinType>,
        royalty_strategy: &mut BpsRoyaltyStrategy<Item>,
        transfer_policy: &mut TransferPolicy<Item>,
        seller_kiosk: &mut Kiosk,
        buyer_kiosk: &mut Kiosk,
        nft_id: ID,
        price: u64,
        wallet: &mut Coin<CoinType>,
        ctx: &mut TxContext
    ){
        let market_fee = price * ob_market.fee / 10000;
        assert!(coin::value(wallet) == market_fee + price, EAmountOfMoney);
        let market_coin = coin::split(wallet, market_fee, ctx);
        public_transfer(market_coin, ob_market.beneficiary);
        let ob_transfer_request = orderbook::buy_nft<Item, CoinType>(book, seller_kiosk, buyer_kiosk, nft_id, price, wallet, ctx);
        royalty_strategy_bps::confirm_transfer<Item, CoinType>(royalty_strategy, &mut ob_transfer_request);
        transfer_request::confirm<Item, CoinType>(ob_transfer_request, transfer_policy, ctx);
    }

    public entry fun ob_buy_without_ruler<Item: key+store, CoinType>(
        ob_market: &ObMarketplace,
        book: &mut Orderbook<Item, CoinType>,
        transfer_policy: &mut TransferPolicy<Item>,
        seller_kiosk: &mut Kiosk,
        buyer_kiosk: &mut Kiosk,
        nft_id: ID,
        price: u64,
        wallet: &mut Coin<CoinType>,
        ctx: &mut TxContext
    ){
        let market_fee = price * ob_market.fee / 10000;
        assert!(coin::value(wallet) == market_fee + price, EAmountOfMoney);
        let market_coin = coin::split(wallet, market_fee, ctx);
        public_transfer(market_coin, ob_market.beneficiary);
        let ob_transfer_request = orderbook::buy_nft<Item, CoinType>(book, seller_kiosk, buyer_kiosk, nft_id, price, wallet, ctx);
        transfer_request::confirm<Item, CoinType>(ob_transfer_request, transfer_policy, ctx);
    }


    public entry fun ob_bid<Item: key+store, CoinType>(
        ob_market: &ObMarketplace,
        book: &mut Orderbook<Item, CoinType>,
        buyer_kiosk: &mut Kiosk,
        price: u64,
        wallet: Coin<CoinType>,
        ctx: &mut TxContext
    ){
        let market_fee = price * ob_market.fee / 10000;
        let bid_price = price - market_fee;
        orderbook::create_bid_with_commission<Item, CoinType>(book, buyer_kiosk, bid_price, ob_market.beneficiary, market_fee, &mut wallet, ctx);
        coin::destroy_zero(wallet);
    }

    public entry fun ob_cancel_bid<Item: key+store, CoinType>(
        book: &mut Orderbook<Item, CoinType>,
        price: u64,
        ctx: &mut TxContext
    ){
        let wallet = coin::zero<CoinType>(ctx);
        orderbook::cancel_bid<Item, CoinType>(book, price, &mut wallet, ctx);
        public_transfer(wallet, sender(ctx))
    }

    public entry fun ob_accept_bid<Item: key+store, CoinType>(
        book: &mut Orderbook<Item, CoinType>,
        allow_list: &Allowlist,
        royalty_strategy: &mut BpsRoyaltyStrategy<Item>,
        transfer_policy: &mut TransferPolicy<Item>,
        seller_kiosk: &mut Kiosk,
        buyer_kiosk: &mut Kiosk,
        nft_id: ID,
        price: u64,
        ctx: &mut TxContext
    ){
        let trade_info = orderbook::market_sell<Item, CoinType>(book, seller_kiosk, price, nft_id, ctx);
        let trade_id = orderbook::trade_id(&trade_info);
        let ob_transfer_request = orderbook::finish_trade(book, trade_id, seller_kiosk, buyer_kiosk, ctx);
        transfer_allowlist::confirm_transfer(allow_list, &mut ob_transfer_request);
        royalty_strategy_bps::confirm_transfer<Item, CoinType>(royalty_strategy, &mut ob_transfer_request);
        transfer_request::confirm<Item, CoinType>(ob_transfer_request, transfer_policy, ctx);
    }



}
