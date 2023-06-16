// Copyright 2019-2022 SwiftNFT Systems
// SPDX-License-Identifier: Apache-2.0
module swift_market::launchpad_v2 {
    use sui::object::{UID, ID};
    use sui::coin::Coin;
    use std::vector;
    use sui::tx_context::{TxContext, sender};
    use sui::object;
    use sui::tx_context;
    use sui::clock;
    use sui::clock::Clock;
    use sui::transfer;
    use sui::coin;
    use sui::pay;
    use sui::vec_map::VecMap;
    use sui::vec_map;
    use swift_market::launchpad_whitelist::{check_whitelist, Activity, ActivityList};
    use swift_market::launchpad_whitelist;
    use swift_market::launchpad_v2_slingshot;
    use swift_market::launchpad_event;
    use swift_market::launchpad_v2_slingshot::{Slingshot, LaunchpadCap};

    struct Launchpad<phantom Item, phantom CoinType>has key, store {
        id: UID,
        start_time: u64,
        end_time: u64,
        minted_count: u64,
        max_count: u64,
        allow_count: u64,
        price: u64,
        is_whitelist: bool,
        claimed: VecMap<address, u64>,
        balance: Coin<CoinType>
    }

    struct MintCap<phantom Item> has key, store {
        id: UID,
        num: u64
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


    public entry fun create_multi_sales_launchpad<Item: key+store, CoinType>(
        manager: &LaunchpadCap<Launchpad<Item, CoinType>>,
        admin: address,
        whitelists: vector<bool>,
        max_counts: vector<u64>,
        start_times: vector<u64>,
        end_times: vector<u64>,
        allow_counts: vector<u64>,
        prices: vector<u64>,
        ctx: &mut TxContext
    ) {
        let result = vector::empty<Launchpad<Item, CoinType>>();
        let launchpad_ids = vector::empty<ID>();
        while (vector::length(&prices) > 0) {
            let start_time = vector::pop_back(&mut start_times);
            let end_time = vector::pop_back(&mut end_times);
            let price = vector::pop_back(&mut prices);
            let is_whitelist = vector::pop_back(&mut whitelists);
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
                is_whitelist,
                claimed: vec_map::empty(),
                balance: coin::zero<CoinType>(ctx),
            };
            let launchpad_id = object::id(&launchpad);
            vector::push_back(&mut result, launchpad);
            vector::push_back(&mut launchpad_ids, launchpad_id);
        };
        let (slingshot_id, market_fee) = launchpad_v2_slingshot::create_slingshot<Launchpad<Item, CoinType>>(manager, admin, true,  result, ctx);
        launchpad_event::slingshot_create_event(
            slingshot_id,
            admin,
            true,
            market_fee,
            launchpad_ids,
        );
    }

    public entry fun remove_launchpads<Item: key+store, CoinType>(
        slingshot: &mut Slingshot,
        launchpad_ids: vector<ID>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let admin = launchpad_v2_slingshot::borrow_admin(slingshot);
        assert!(admin == tx_context::sender(ctx), EOperateNotAuth);
        let i = 0;
        let length = vector::length(&launchpad_ids);
        while (i < length) {
            let launchpad_id = vector::pop_back(&mut launchpad_ids);
            let launchpad = launchpad_v2_slingshot::remove_launchpad<Launchpad<Item, CoinType>>(slingshot, launchpad_id);
            assert!(launchpad.start_time > clock::timestamp_ms(clock), EMarketSaleAlreadyStart);
            transfer::public_transfer(launchpad, tx_context::sender(ctx));
            i = i + 1
        };

        launchpad_event::sale_remove_event(
            object::id(slingshot),
            launchpad_ids,
            tx_context::sender(ctx)
        );
    }

    public entry fun adjust_price<Item: key+store, CoinType>(
        slingshot: &mut Slingshot,
        launchpad_id: ID,
        clock: &Clock,
        price: u64,
        ctx: &mut TxContext
    ) {
        let admin = launchpad_v2_slingshot::borrow_admin(slingshot);
        let borrow_mut_launchpad = launchpad_v2_slingshot::borrow_mut_launchpad<Launchpad<Item,CoinType>>(slingshot, launchpad_id);
        assert!(admin == tx_context::sender(ctx), EOperateNotAuth);
        assert!(borrow_mut_launchpad.start_time > clock::timestamp_ms(clock), ETimeMismatch);
        borrow_mut_launchpad.price = price;
        // slingshot_market_event::item_adjust_price_event<Item, Launchpad<Item, CoinType>>(
        //     object::id(slingshot),
        //     sale_id,
        //     price,
        //     tx_context::sender(ctx)
        // )
    }

    public entry fun withdraw<Item: key+store, CoinType>(
        slingshot: &mut Slingshot,
        launchpad_id: ID,
        receiver: address,
        ctx: &mut TxContext
    ) {
        let admin = launchpad_v2_slingshot::borrow_admin(slingshot);
        assert!(admin == tx_context::sender(ctx), EOperateNotAuth);
        let launchpad = launchpad_v2_slingshot::borrow_mut_launchpad<Launchpad<Item, CoinType>>(slingshot, launchpad_id);
        let balances = coin::value(&launchpad.balance);
        let coins = coin::split(&mut launchpad.balance, balances, ctx);
        transfer::public_transfer(coins, receiver)
    }

    public entry fun delete_mint_cap<Item>(mint_cap: MintCap<Item>) {
        let MintCap<Item> { id, num: _, } = mint_cap;
        object::delete(id);
    }

    fun purchase<Item: key+store, CoinType>(
        slingshot: &mut Slingshot,
        launchpad_id: ID,
        clock: &Clock,
        buyer_funds: &mut Coin<CoinType>,
        mint_cap: &mut MintCap<Item>,
        ctx: &mut TxContext
    ) {
        let live = launchpad_v2_slingshot::borrow_live(slingshot);
        assert!(live, ESlingshotNotLive);
        let addr = sender(ctx);
        let market_fee = launchpad_v2_slingshot::borrow_market_fee(slingshot);
        let launchpad = launchpad_v2_slingshot::borrow_mut_launchpad<Launchpad<Item, CoinType>>(slingshot, launchpad_id);
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
        if (vec_map::contains(&launchpad.claimed, &addr) == true) {
            let (_, claimed_count) = vec_map::remove(&mut launchpad.claimed, &addr);
            assert!(claimed_count < launchpad.allow_count, EMintInsufficient);
            vec_map::insert(&mut launchpad.claimed, addr, claimed_count + 1);
        }else{
            vec_map::insert(&mut launchpad.claimed, addr, 1);
        };
        launchpad.minted_count = launchpad.minted_count + 1;
        pay::join(&mut launchpad.balance, fund);
        // slingshot_market_event::item_purchased_event<Item, SlingshotMarket<Item, CoinType>>(
        //     object::id(slingshot),
        //     sale_id,
        //     item_id,
        //     price,
        //     tx_context::sender(ctx)
        // );
        mint_cap.num = mint_cap.num + 1;
    }

    public fun purchase_without_whitelist<Item: key+store, CoinType>(
        slingshot: &mut Slingshot,
        launchpad_id: ID,
        count: u64,
        clock: &Clock,
        buyer_funds: &mut Coin<CoinType>,
        ctx: &mut TxContext
    ): MintCap<Item> {
        let launchpad = launchpad_v2_slingshot::borrow_launchpad<Launchpad<Item,CoinType>>(slingshot, launchpad_id);
        assert!(!launchpad.is_whitelist, ENotAuthGetWhiteList);
        let mint_cap = MintCap<Item>{ id: object::new(ctx), num: 0 };
        while (count > 0) {
            purchase(slingshot, launchpad_id, clock, buyer_funds, &mut mint_cap, ctx);
            count = count -1;
        };
        mint_cap
    }

    public fun purchase_with_whitelist<Item: key+store, CoinType>(
        slingshot: &mut Slingshot,
        launchpad_id: ID,
        count: u64,
        clock: &Clock,
        activity: &Activity,
        proof: vector<vector<u8>>,
        buyer_funds: &mut  Coin<CoinType>,
        ctx: &mut TxContext
    ): MintCap<Item> {
        let launchpad = launchpad_v2_slingshot::borrow_launchpad<Launchpad<Item,CoinType>>(slingshot, launchpad_id);
        assert!(launchpad.is_whitelist, ENotAuthGetWhiteList);
        assert!(check_whitelist(activity, proof, ctx), ENotAuthGetWhiteList);
        let mint_cap = MintCap<Item>{ id: object::new(ctx), num: 0 };
        while (count > 0) {
            purchase(slingshot, launchpad_id, clock, buyer_funds, &mut mint_cap, ctx);
            count = count -1;
        };
        mint_cap
    }

    public entry fun update_whitelist_status<Item: key+store, CoinType>(
        slingshot: &mut Slingshot,
        launchpad_id: ID,
        status: bool,
        ctx: &mut TxContext
    ) {
        let admin = launchpad_v2_slingshot::borrow_admin(slingshot);
        assert!(admin == tx_context::sender(ctx), EOperateNotAuth);
        let launchpad = launchpad_v2_slingshot::borrow_mut_launchpad<Launchpad<Item, CoinType>>(slingshot, launchpad_id);
        launchpad.is_whitelist = status
        //
        // sale_event::wl_status_change_event<Item, Launchpad>(object::id(sales), true)
    }

    public entry fun create_whitelist<Item: key+store, CoinType>(
        slingshot: &mut Slingshot,
        activity_list:&mut ActivityList,
        sale_id: ID,
        root: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let admin = launchpad_v2_slingshot::borrow_admin(slingshot);
        assert!(admin == tx_context::sender(ctx), EOperateNotAuth);
        launchpad_whitelist::create_activity(activity_list, sale_id, root, url, ctx);
    }

    public entry fun modify_whitelist<Item: key+store, CoinType>(
        slingshot: &mut Slingshot,
        activity: &mut Activity,
        root: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let admin = launchpad_v2_slingshot::borrow_admin(slingshot);
        assert!(admin == tx_context::sender(ctx), EOperateNotAuth);
        launchpad_whitelist::modify_activity(activity, root, url);
    }



    public entry fun mint_cap_inner_num<Item: key+store>(mint_cap: &MintCap<Item>): u64{
        mint_cap.num
    }

}