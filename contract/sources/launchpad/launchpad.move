// Copyright 2019-2022 SwiftNFT Systems
// SPDX-License-Identifier: Apache-2.0
module swift_market::launchpad {
    use sui::object::{UID, ID};
    use sui::coin::Coin;
    use std::vector;
    use sui::tx_context::{TxContext, sender};
    use sui::object;
    use sui::tx_context;
    use swift_market::launchpad_event;
    use swift_market::launchpad_sale;
    use swift_market::launchpad_slingshot;
    use swift_market::launchpad_slingshot::{Slingshot};
    use sui::clock;
    use sui::clock::Clock;
    use sui::transfer;
    use sui::coin;
    use sui::pay;
    use sui::vec_map::VecMap;
    use sui::vec_map;
    use sui::transfer::public_transfer;
    use swift_market::launchpad_whitelist::{check_whitelist, Activity, ActivityList};
    use swift_market::launchpad_whitelist;
    use swift_market::launchpad_sale::modify_whitelist_status;

    struct Launchpad<phantom Item, phantom CoinType>has key, store {
        id: UID,
        start_time: u64,
        end_time: u64,
        minted_count: u64,
        max_count: u64,
        allow_count: u64,
        price: u64,
        claimed: VecMap<address, u64>,
        balance: Coin<CoinType>
    }

    struct SwiftNftLaunchpadManagerCap has key, store {
        id: UID,
        market_fee: u64
    }

    const MarketFee: u64 = 5;


    const EMarketSaleAlreadyStart: u64 = 0;
    const ESalesFundsInsufficient: u64 = 1;
    const ETimeMismatch: u64 = 2;
    const EMintInsufficient: u64 = 3;
    const ESTwoalesMisMatch: u64 = 4;
    const EOperateNotAuth: u64 = 5;
    const ENotAuthGetWhiteList: u64 = 6;
    const ESlingshotNotLive: u64 = 7;


    fun init(ctx: &mut TxContext) {
        transfer::public_transfer(SwiftNftLaunchpadManagerCap {
            id: object::new(ctx),
            market_fee: 5
        }, sender(ctx));
    }


    public entry fun create_multi_sales_launchpad<Item: key+store, CoinType>(
        manager: &SwiftNftLaunchpadManagerCap,
        admin: address,
        live: bool,
        whitelists: vector<bool>,
        max_counts: vector<u64>,
        start_times: vector<u64>,
        end_times: vector<u64>,
        allow_counts: vector<u64>,
        prices: vector<u64>,
        ctx: &mut TxContext
    ) {
        let result = vector::empty<launchpad_sale::Sale<Item, Launchpad<Item, CoinType>>>();
        let sale_ids = vector::empty<ID>();
        while (vector::length(&prices) > 0) {
            let start_time = vector::pop_back(&mut start_times);
            let end_time = vector::pop_back(&mut end_times);
            let price = vector::pop_back(&mut prices);
            let whitelist = vector::pop_back(&mut whitelists);
            let max_count = vector::pop_back(&mut max_counts);
            let allow_count = vector::pop_back(&mut allow_counts);

            let launchpad = Launchpad<Item, CoinType> {
                id: object::new(ctx),
                start_time,
                end_time,
                minted_count: 0,
                max_count,
                allow_count,
                price,
                claimed: vec_map::empty(),
                balance: coin::zero<CoinType>(ctx),
            };
            let launchpad_id = object::id(&launchpad);
            let new_sale = launchpad_sale::create_sale<Item, Launchpad<Item, CoinType>>(whitelist, launchpad, ctx);
            let sale_id = object::id(&new_sale);
            launchpad_event::sale_create_event(sale_id, launchpad_id, whitelist, start_time, end_time, price);
            vector::push_back(&mut sale_ids, sale_id);
            vector::push_back(&mut result, new_sale);
        };
        let slingshot_id = launchpad_slingshot::create_slingshot<Item, Launchpad<Item, CoinType>>(admin, live, manager.market_fee, result, ctx);
        launchpad_event::slingshot_create_event(
            slingshot_id,
            admin,
            live,
            manager.market_fee,
            sale_ids,
        );
    }

    public entry fun remove_sale<Item: key+store, CoinType>(
        slingshot: &mut Slingshot<Item, Launchpad<Item, CoinType>>,
        sale_ids: vector<ID>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let admin = launchpad_slingshot::borrow_admin(slingshot);
        assert!(admin == tx_context::sender(ctx), EOperateNotAuth);
        let i = 0;
        let length = vector::length(&sale_ids);
        while (i < length) {
            let sale_id = vector::pop_back(&mut sale_ids);
            let borrow_mut_sale = launchpad_slingshot::borrow_mut_sales(slingshot, sale_id);
            let mut_market = launchpad_sale::get_mut_market<Item, Launchpad<Item, CoinType>>(borrow_mut_sale);
            assert!(mut_market.start_time > clock::timestamp_ms(clock), EMarketSaleAlreadyStart);
            let sale = launchpad_slingshot::remove_sales(slingshot, sale_id);
            transfer::public_transfer(sale, tx_context::sender(ctx));
            i = i + 1
        };

        launchpad_event::sale_remove_event(
            object::id(slingshot),
            sale_ids,
            tx_context::sender(ctx)
        );
    }

    public entry fun adjust_price<Item: key+store, CoinType>(
        slingshot: &mut Slingshot<Item, Launchpad<Item, CoinType>>,
        sale_id: ID,
        clock: &Clock,
        price: u64,
        ctx: &mut TxContext
    ) {
        let admin = launchpad_slingshot::borrow_admin(slingshot);
        assert!(admin == tx_context::sender(ctx), EOperateNotAuth);
        let borrow_sale = launchpad_slingshot::borrow_sales(slingshot, sale_id, ctx);
        let market = launchpad_sale::get_launchpad(borrow_sale);
        assert!(market.start_time > clock::timestamp_ms(clock), ETimeMismatch);
        let borrow_mut_sale = launchpad_slingshot::borrow_mut_sales(slingshot, sale_id);
        let mut_market = launchpad_sale::get_mut_market<Item, Launchpad<Item, CoinType>>(borrow_mut_sale);

        mut_market.price = price;
        // slingshot_market_event::item_adjust_price_event<Item, Launchpad<Item, CoinType>>(
        //     object::id(slingshot),
        //     sale_id,
        //     price,
        //     tx_context::sender(ctx)
        // )
    }

    public entry fun withdraw<Item: key+store, CoinType>(
        slingshot: &mut Slingshot<Item, Launchpad<Item, CoinType>>,
        sale_id: ID,
        receiver: address,
        ctx: &mut TxContext
    ) {
        let admin = launchpad_slingshot::borrow_admin(slingshot);
        assert!(admin == tx_context::sender(ctx), EOperateNotAuth);
        let borrow_mut_sale = launchpad_slingshot::borrow_mut_sales(slingshot, sale_id);
        let launchpad = launchpad_sale::get_mut_market<Item, Launchpad<Item, CoinType>>(borrow_mut_sale);
        let balances = coin::value(&launchpad.balance);
        let coins = coin::split(&mut launchpad.balance, balances, ctx);
        transfer::public_transfer(coins, receiver)
    }

    public entry fun list_item<Item: key+store, CoinType>(
        slingshot: &mut Slingshot<Item, Launchpad<Item, CoinType>>,
        sale_id: ID,
        clock: &Clock,
        nfts: vector<Item>,
        ctx: &mut TxContext
    ) {
        let admin = launchpad_slingshot::borrow_admin(slingshot);
        assert!(admin == tx_context::sender(ctx), EOperateNotAuth);
        let borrow_sale = launchpad_slingshot::borrow_mut_sales(slingshot, sale_id);
        let launchpad = launchpad_sale::get_mut_market<Item, Launchpad<Item, CoinType>>(borrow_sale);
        assert!(clock::timestamp_ms(clock) < launchpad.start_time, ETimeMismatch);
        launchpad_sale::list_multi_item(borrow_sale, nfts);
    }

    public entry fun delist_item<Item: key+store, CoinType>(
        slingshot: &mut Slingshot<Item, Launchpad<Item, CoinType>>,
        sale_id: ID,
        clock: &Clock,
        nfts: vector<ID>,
        ctx: &mut TxContext
    ) {
        let admin = launchpad_slingshot::borrow_admin(slingshot);
        assert!(admin == tx_context::sender(ctx), EOperateNotAuth);
        let borrow_sale = launchpad_slingshot::borrow_mut_sales(slingshot, sale_id);
        let launchpad = launchpad_sale::get_mut_market<Item, Launchpad<Item, CoinType>>(borrow_sale);
        assert!(clock::timestamp_ms(clock) < launchpad.start_time, ETimeMismatch);
        let items = launchpad_sale::delist_item(borrow_sale, nfts);
        while (vector::length(&items) > 0) {
            let item = vector::pop_back(&mut items);
            public_transfer(item, sender(ctx));
        };
        vector::destroy_empty(items);
    }



    fun purchase<Item: key+store, CoinType>(
        slingshot: &mut Slingshot<Item, Launchpad<Item, CoinType>>,
        sale_id: ID,
        clock: &Clock,
        buyer_funds: &mut Coin<CoinType>,
        ctx: &mut TxContext
    ) {
        let live = launchpad_slingshot::borrow_live(slingshot);
        assert!(live, ESlingshotNotLive);
        let addr = sender(ctx);
        let market_fee = launchpad_slingshot::borrow_market_fee(slingshot);
        let borrow_sale = launchpad_slingshot::borrow_sales(slingshot, sale_id, ctx);
        let launchpad = launchpad_sale::get_launchpad<Item, Launchpad<Item, CoinType>>(borrow_sale);
        assert!(coin::value(buyer_funds) == launchpad.price, ESalesFundsInsufficient);
        assert!(clock::timestamp_ms(clock) >= launchpad.start_time, ETimeMismatch);
        assert!(clock::timestamp_ms(clock) <= launchpad.end_time, ETimeMismatch);
        assert!(launchpad.minted_count < launchpad.max_count, EMintInsufficient);
        let market_price = launchpad.price * market_fee / 100;
        let price = launchpad.price - market_price;
        if (market_price > 0) {
            pay::split_and_transfer(buyer_funds, market_price, sender(ctx), ctx);
        };
        let fund = coin::split(buyer_funds, price, ctx);
        let borrow_mut_sale = launchpad_slingshot::borrow_mut_sales<Item, Launchpad<Item, CoinType>>(slingshot, sale_id);
        let item = launchpad_sale::withdraw(borrow_mut_sale, ctx);
        let mut_launchpad = launchpad_sale::get_mut_market<Item, Launchpad<Item, CoinType>>(borrow_mut_sale);
        if (vec_map::contains(&mut_launchpad.claimed, &addr) == true) {
            let (_, claimed_count) = vec_map::remove(&mut mut_launchpad.claimed, &addr);
            assert!(claimed_count < mut_launchpad.allow_count, EMintInsufficient);
            vec_map::insert(&mut mut_launchpad.claimed, addr, claimed_count + 1);
        }else{
            vec_map::insert(&mut mut_launchpad.claimed, addr, 1);
        };
        mut_launchpad.minted_count = mut_launchpad.minted_count + 1;
        let sale_coin = &mut launchpad_sale::get_mut_market<Item, Launchpad<Item, CoinType>>(borrow_mut_sale).balance;
        pay::join(sale_coin, fund);
        // slingshot_market_event::item_purchased_event<Item, SlingshotMarket<Item, CoinType>>(
        //     object::id(slingshot),
        //     sale_id,
        //     item_id,
        //     price,
        //     tx_context::sender(ctx)
        // );
        transfer::public_transfer(item, tx_context::sender(ctx));
    }

    public entry fun multi_purchase<Item: key+store, CoinType>(
        slingshot: &mut Slingshot<Item, Launchpad<Item, CoinType>>,
        sale_id: ID,
        count: u64,
        clock: &Clock,
        buyer_funds: &mut Coin<CoinType>,
        ctx: &mut TxContext
    ) {
        let borrow_sale = launchpad_slingshot::borrow_sales(slingshot, sale_id, ctx);
        let whitelist = launchpad_sale::whitelist_status(borrow_sale);
        assert!(!whitelist, ENotAuthGetWhiteList);
        let i = 0;
        while (i < count) {
            purchase(slingshot, sale_id, clock, buyer_funds, ctx);
            i = i + 1;
        }
    }

    public entry fun whitelist_purchase<Item: key+store, CoinType>(
        slingshot: &mut Slingshot<Item, Launchpad<Item, CoinType>>,
        sale_id: ID,
        count: u64,
        clock: &Clock,
        activity: &Activity,
        proof: vector<vector<u8>>,
        buyer_funds: &mut Coin<CoinType>,
        ctx: &mut TxContext
    ) {
        let borrow_sale = launchpad_slingshot::borrow_sales(slingshot, sale_id, ctx);
        let whitelist = launchpad_sale::whitelist_status(borrow_sale);
        if (whitelist == true) {
            let is_whitelist = check_whitelist(activity, proof, ctx);
            assert!(is_whitelist, ENotAuthGetWhiteList);
        };
        let i = 0;
        while (i < count) {
            purchase(slingshot, sale_id, clock, buyer_funds, ctx);
            i = i + 1;
        }
    }

    public entry fun update_whitelist_status<Item: key+store, CoinType>(
        slingshot: &mut Slingshot<Item, Launchpad<Item, CoinType>>,
        sale_id: ID,
        status: bool,
        ctx: &mut TxContext
    ) {
        let admin = launchpad_slingshot::borrow_admin(slingshot);
        assert!(admin == tx_context::sender(ctx), EOperateNotAuth);
        let borrow_mut_sale = launchpad_slingshot::borrow_mut_sales<Item, Launchpad<Item, CoinType>>(slingshot, sale_id);
        modify_whitelist_status(borrow_mut_sale, status);
        //
        // sale_event::wl_status_change_event<Item, Launchpad>(object::id(sales), true)
    }

    public entry fun create_whitelist<Item: key+store, CoinType>(
        slingshot: &Slingshot<Item, Launchpad<Item, CoinType>>,
        activity_list:&mut ActivityList,
        sale_id: ID,
        root: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let admin = launchpad_slingshot::borrow_admin(slingshot);
        assert!(admin == tx_context::sender(ctx), EOperateNotAuth);
        launchpad_whitelist::create_activity(activity_list, sale_id, root, url, ctx);
    }

    public entry fun modify_whitelist<Item: key+store, CoinType>(
        slingshot: &Slingshot<Item, Launchpad<Item, CoinType>>,
        activity: &mut Activity,
        root: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let admin = launchpad_slingshot::borrow_admin(slingshot);
        assert!(admin == tx_context::sender(ctx), EOperateNotAuth);
        launchpad_whitelist::modify_activity(activity, root, url);
    }

    public entry fun send_manager(manager: SwiftNftLaunchpadManagerCap, receiver: address){
        transfer::public_transfer(manager, receiver);
    }

}