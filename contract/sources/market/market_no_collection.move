// Copyright 2019-2022 SwiftNFT Systems
// SPDX-License-Identifier: Apache-2.0
module swift_market::market {
    use sui::object::{Self, ID, UID};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext, sender};
    use sui::dynamic_object_field as dof;
    use sui::pay;
    use std::vector;
    use swift_market::market_event;
    use swift_market::err_code;
    use std::type_name;
    use sui::package;
    use std::ascii::String;
    use sui::package::Publisher;

    // One-Time-Witness for the module.
    struct MARKET has drop {}

    const VERSION: u64 = 1;

    const EWrongVersion: u64 = 1;

    const EBpsExceed:u64 = 2;

    //let explicit_u8 = 1u8;
    ///Some basic information about Item's listing  in the market
    struct Listing has store, key {
        id: UID,
        /// The Item of price
        price: u64,
        /// The Item of owner
        seller: address,
    }

    ///Some basic information about Collection
    struct Collection<phantom Item: key+store, phantom CoinType> has key, store {
        id: UID,
    }


    struct RoyaltyCollection has key {
        id: UID
    }

    struct CollectionRoyaltyStrategy<phantom Item: key+store, phantom CoinType> has key, store {
        id: UID,
        /// Address that created this collection and As the administrator of the Collection
        beneficiary: address,
        /// Royalties collected by collction
        balance: Coin<CoinType>,
        /// Royalty fee of the collection
        bps: u64
    }



    ///Record some important information of the market
    struct Marketplace<phantom CoinType> has key {
        id: UID,
        /// version of market
        version: u64,
        ///marketplace fee collected by marketplace
        balance: Coin<CoinType>,
        ///marketplace fee  of the marketplace
        fee: u64,
    }

    struct AdminCap has key, store {
        id: UID,
    }


    public entry fun createMarket<CoinType>(_publish: &Publisher, fee: u64, ctx: &mut TxContext){
        let market = Marketplace {
            id: object::new(ctx),
            version: VERSION,
            balance: coin::zero<SUI>(ctx),
            fee,
        };
        let collection_list = RoyaltyCollection{ id: object::new(ctx), };
        market_event::market_created_event(object::id(&market), object::id(&collection_list), tx_context::sender(ctx));
        transfer::share_object(market);
        transfer::share_object(collection_list);
    }

    fun init(otw: MARKET, ctx: &mut TxContext) {
        //Initialize the marketplace object and set the marketpalce fee
        let market = Marketplace {
            id: object::new(ctx),
            version: VERSION,
            balance: coin::zero<SUI>(ctx),
            fee: 150,
        };
        // Claim the `Publisher` for the package!
        let publisher = package::claim(otw, ctx);
        transfer::public_transfer(publisher, sender(ctx));
        let collection_list = RoyaltyCollection{
            id: object::new(ctx),
        };
        market_event::market_created_event(object::id(&market), object::id(&collection_list), tx_context::sender(ctx));

        transfer::share_object(market);
        transfer::share_object(collection_list);
        transfer::public_transfer(AdminCap { id: object::new(ctx) }, tx_context::sender(ctx));
    }

    ///Listing NFT in the collection
    public entry fun list<Item: store+key, CoinType>(
        market: &mut Marketplace<CoinType>,
        item: Item,
        price: u64,
        ctx: &mut TxContext
    ) {
        let item_id = object::id(&item);
        let listing = Listing {
            id: object::new(ctx),
            price,
            seller: tx_context::sender(ctx),
        };
        let listing_id = object::id(&listing);
        let nft_type = type_name::into_string(type_name::get<Item>());
        let ft_type = type_name::into_string(type_name::get<CoinType>());
        let is_new_collection = false;
        if (!dof::exists_(&market.id, nft_type)){
            let collection = Collection<Item, CoinType>{ id: object::new(ctx) };
            dof::add(&mut market.id, nft_type, collection);
            is_new_collection = true;
        };
        let collection = dof::borrow_mut<String, Collection<Item, CoinType>>(&mut market.id, nft_type);
        dof::add(&mut listing.id, item_id, item);
        dof::add(&mut collection.id, item_id, listing);
        market_event::item_list_event(object::id(collection), item_id, listing_id, tx_context::sender(ctx), price, nft_type, ft_type, is_new_collection);
    }

    ///Listing NFT in the collection
    public fun batch_list<Item: store+key, CoinType>(
        market: &mut Marketplace<CoinType>,
        items: vector<Item>,
        prices: vector<u64>,
        ctx: &mut TxContext
    ) {
        let length = vector::length(&items);
        let i = 0;
        while (i < length) {
            let item = vector::pop_back(&mut items);
            let price = vector::pop_back(&mut prices);
            list<Item, CoinType>(market, item, price, ctx);
            i = i + 1;
        };
        vector::destroy_empty(items);
    }

    public entry fun add_collection_royalty<Item: store+key, CoinType>(
        collection: &mut RoyaltyCollection,
        beneficiary: address,
        bps: u64,
        ctx: &mut TxContext
    ){
        assert!( bps < 10000, EBpsExceed);
        let royalty_strategy = CollectionRoyaltyStrategy<Item, CoinType>{
            id: object::new(ctx),
            beneficiary,
            balance: coin::zero<CoinType>(ctx),
            bps
        };
        let collection_type_name = type_name::into_string(type_name::get<Item>());
        dof::add(&mut collection.id, collection_type_name, royalty_strategy);
    }

    public entry fun update_collection_royalty<Item: store+key, CoinType>(
        collection: &mut RoyaltyCollection,
        beneficiary: address,
        bps: u64,
    ){
        assert!( bps < 10000, EBpsExceed);
        let collection_type_name = type_name::into_string(type_name::get<Item>());
        let royalty_strategy = dof::borrow_mut<String, CollectionRoyaltyStrategy<Item, CoinType>>(&mut collection.id, collection_type_name);
        royalty_strategy.bps = bps;
        royalty_strategy.beneficiary = beneficiary;
    }

    ///Adjusting the price of NFT
    public entry fun adjust_price<Item: store+key, CoinType>(
        market: &mut Marketplace<CoinType>,
        item_id: ID,
        price: u64,
        ctx: &mut TxContext) {
        let nft_type = type_name::into_string(type_name::get<Item>());
        let ft_type = type_name::into_string(type_name::get<CoinType>());

        let collection=dof::borrow_mut<String, Collection<Item, CoinType>>(&mut market.id, nft_type);
        let collection_id = object::id(collection);
        let listing = dof::borrow_mut<ID, Listing>(&mut collection.id, item_id);
        assert!(listing.seller == tx_context::sender(ctx), err_code::not_auth_operator());
        listing.price = price;
        market_event::item_adjust_price_event(collection_id, item_id, tx_context::sender(ctx), nft_type, ft_type, price);
    }

    ///Cancel the listing of NFT
    public fun delist<Item: store+key, CoinType>(
        market: &mut Marketplace<CoinType>,
        item_id: ID,
        ctx: &mut TxContext
    ): Item {
        let nft_type = type_name::into_string(type_name::get<Item>());
        let ft_type = type_name::into_string(type_name::get<CoinType>());

        let collection=dof::borrow_mut<String, Collection<Item, CoinType>>(&mut market.id, nft_type);
        //Get the list from the collection
        let listing = dof::remove<ID, Listing>(&mut collection.id, item_id);
        let listing_id = object::id(&listing);
        let Listing {
            id,
            price,
            seller,
        } = listing;
        //Determine the owner's authority
        assert!(tx_context::sender(ctx) == seller, err_code::not_auth_operator());
        let item = dof::remove<ID, Item>(&mut id, item_id);
        //emit event
        market_event::item_delisted_event(object::id(collection), item_id, listing_id, tx_context::sender(ctx), nft_type, ft_type, price);

        object::delete(id);
        item
    }


    ///purchase
    public fun buy_script<Item: store+key, CoinType>(
        market: &mut Marketplace<CoinType>,
        royalty_collection: &mut RoyaltyCollection,
        item_id: ID,
        paid: &mut Coin<CoinType>,
        ctx: &mut TxContext
    ): Item {
        let nft_type = type_name::into_string(type_name::get<Item>());
        let ft_type = type_name::into_string(type_name::get<CoinType>());

        let collection=dof::borrow_mut<String, Collection<Item, CoinType>>(&mut market.id, nft_type);
        assert!(market.version == VERSION, EWrongVersion);
        let listing = dof::remove<ID, Listing>(&mut collection.id, item_id);
        let Listing {
            id,
            price,
            seller,
        } = listing;

        assert!(coin::value(paid) >= price, err_code::err_input_amount());

        let market_fee = price * market.fee / 10000;
        let collection_fee = 0;
        if (dof::exists_(&royalty_collection.id, nft_type)){
            let royalty_strategy = dof::borrow_mut<String, CollectionRoyaltyStrategy<Item, CoinType>>(&mut royalty_collection.id, nft_type);
            collection_fee = price * royalty_strategy.bps / 10000;
            let collection_value = coin::split<CoinType>(paid, collection_fee, ctx);
            coin::join(&mut royalty_strategy.balance, collection_value);
        };
        let surplus = price - market_fee - collection_fee;

        assert!(surplus > 0, err_code::err_amount_is_zero());

        pay::split_and_transfer(paid, surplus, seller, ctx);
        let market_value = coin::split<CoinType>(paid, market_fee, ctx);
        coin::join(&mut market.balance, market_value);


        let item = dof::remove<ID, Item>(&mut id, item_id);

        market_event::item_buy_event(object::id(collection), item_id, seller, sender(ctx), nft_type, ft_type, price);

        object::delete(id);
        item
    }

    ///purcahse muti NFT
    public entry fun buy_multi_item_script<Item: store+key, CoinType>(
        market: &mut Marketplace<CoinType>,
        royalty_collection: &mut RoyaltyCollection,
        item_ids: vector<ID>,
        paid: Coin<CoinType>,
        receiver: address,
        ctx: &mut TxContext
    ) {
        while (vector::length(&item_ids) != 0) {
            let ids = vector::pop_back(&mut item_ids);
            buy_and_take_script<Item, CoinType>(market, royalty_collection, ids, &mut paid, receiver, ctx);
        };
        transfer::public_transfer(paid, tx_context::sender(ctx))
    }

    public entry fun buy_and_take_script<Item: store+key, CoinType>(
        market: &mut Marketplace<CoinType>,
        royalty_collection: &mut RoyaltyCollection,
        item_id: ID,
        paid: &mut Coin<CoinType>,
        receiver: address,
        ctx: &mut TxContext
    ) {
        transfer::public_transfer(buy_script<Item, CoinType>(market, royalty_collection, item_id, paid, ctx), receiver)
    }

    public entry fun collect_profit_collection<Item: key+store, CoinType>(
        collection: &mut RoyaltyCollection,
        receiver: address,
        ctx: &mut TxContext
    ) {
        let nft_type = type_name::into_string(type_name::get<Item>());
        let ft_type = type_name::into_string(type_name::get<CoinType>());

        let royalty_strategy = dof::borrow_mut<String, CollectionRoyaltyStrategy<Item, CoinType>>(&mut collection.id, nft_type);
        assert!(tx_context::sender(ctx) == royalty_strategy.beneficiary, err_code::not_auth_operator());
        let balances = coin::value(&mut royalty_strategy.balance);
        let coins = coin::split(&mut royalty_strategy.balance, balances, ctx);
        transfer::public_transfer(coins, receiver);
        market_event::collection_withdrawal(object::id(collection), sender(ctx), receiver, nft_type, ft_type, balances);
    }

    public entry fun collect_profits<CoinType>(
        _admin: &AdminCap,
        market: &mut Marketplace<CoinType>,
        receiver: address,
        ctx: &mut TxContext
    ) {
        assert!(market.version == VERSION, EWrongVersion);
        let balances = coin::value(&mut market.balance);
        let coins = coin::split(&mut market.balance, balances, ctx);
        transfer::public_transfer(coins, receiver);
    }

    public entry fun delist_take<Item: key + store, CoinType>(
        market: &mut Marketplace<CoinType>,
        item_id: ID,
        ctx: &mut TxContext
    ) {
        let item = delist<Item, CoinType>(market, item_id, ctx);
        transfer::public_transfer(item, tx_context::sender(ctx));
    }

    public entry fun delist_take_receiver<Item: key + store, CoinType>(
        market: &mut Marketplace<CoinType>,
        item_id: ID,
        receiver: address,
        ctx: &mut TxContext
    ) {
        let item = delist<Item, CoinType>(market, item_id, ctx);
        transfer::public_transfer(item, receiver);
    }



    public entry fun update_market_fee<CoinType>(
        _admin: &AdminCap,
        market: &mut Marketplace<CoinType>,
        fee: u64,
        _ctx: &mut TxContext
    ) {
        assert!(market.version == VERSION, EWrongVersion);
        market.fee = fee
    }

    public entry fun change_admin(
        admin: AdminCap,
        receiver: address,
    ){
        transfer::public_transfer(admin, receiver);
    }

    // public fun to_string_vector(
    //     vec: &mut vector<vector<u8>>
    // ): vector<string::String>
    // {
    //     let new_vec: vector<string::String> = vector::empty();
    //
    //     let len = vector::length(vec);
    //
    //     if (len == 0) {
    //         return new_vec
    //     };
    //
    //     let i = 0;
    //     while (i < len) {
    //         let e = string::utf8(vector::pop_back(vec));
    //         vector::push_back(&mut new_vec, e);
    //         i = i + 1;
    //     };
    //     vector::reverse(&mut new_vec);
    //     new_vec
    // }
}
