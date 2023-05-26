// Copyright 2019-2022 SwiftNFT Systems
// SPDX-License-Identifier: Apache-2.0
module swift_nft::launchpad_slingshot {

    use sui::object::{Self, UID, ID};
    use sui::object_table::{Self, ObjectTable};
    use swift_nft::launchpad_sale::Sale;
    use sui::tx_context::TxContext;
    use sui::transfer;
    use std::vector;
    use sui::tx_context;
    friend swift_nft::launchpad;


    struct Slingshot<phantom Item: key+store, Launchpad: store> has key, store {
        id: UID,
        admin: address,
        live: bool,
        market_fee: u64,
        sales: ObjectTable<ID, Sale<Item, Launchpad>>
    }

    const EOperateNotAuth: u64 = 0;



    public(friend) fun create_slingshot<Item: key+store, Launchpad: store>(
        admin: address,
        live: bool,
        market_fee: u64,
        sales: vector<Sale<Item, Launchpad>>,
        ctx: &mut TxContext
    ): ID {
        let slingshot = Slingshot<Item, Launchpad> {
            id: object::new(ctx),
            admin,
            live,
            market_fee,
            sales: object_table::new(ctx),
        };
        let length = vector::length(&sales);
        let i = 0;
        while (i < length) {
            let pop_sales = vector::pop_back(&mut sales);
            let sale_id = object::id(&pop_sales);
            object_table::add(&mut slingshot.sales, sale_id, pop_sales);
            i = i + 1
        };
        vector::destroy_empty(sales);
        let slingshot_id = object::id(&slingshot);
        transfer::share_object(slingshot);

        return slingshot_id
    }

    public fun add_multi_sales<Item: key+store, Launchpad: store>(
        slingshot: &mut Slingshot<Item, Launchpad>,
        sales: vector<Sale<Item, Launchpad>>,
        ctx: &mut TxContext
    ) {
        assert!(slingshot.admin == tx_context::sender(ctx), EOperateNotAuth);
        let length = vector::length(&sales);
        let sale_vec = vector::empty<ID>();

        let i = 0;
        while (i < length) {
            let pop_sales = vector::pop_back(&mut sales);
            let sale_id = object::id(&pop_sales);
            vector::push_back(&mut sale_vec, sale_id);
            object_table::add(&mut slingshot.sales, sale_id, pop_sales);
            i = i + 1
        };
        // launchpad_event::sales_add_event<Item, Launchpad>(object::id(slingshot), sale_vec);
        vector::destroy_empty(sales);
    }

    public(friend) fun remove_sales<Item: key+store, Launchpad: store>(
        slingshot: &mut Slingshot<Item, Launchpad>,
        sale_id: ID
    ): Sale<Item, Launchpad> {
        object_table::remove(&mut slingshot.sales, sale_id)
    }

    public(friend) fun borrow_mut_sales<Item: key+store, Launchpad: store>(
        slingshot: &mut Slingshot<Item, Launchpad>,
        sales_id: ID,
    ): &mut Sale<Item, Launchpad> {
        object_table::borrow_mut(&mut slingshot.sales, sales_id)
    }

    public fun borrow_sales<Item: key+store, Launchpad: store>(
        slingshot: &Slingshot<Item, Launchpad>,
        sales_id: ID,
        ctx: &mut TxContext
    ): &Sale<Item, Launchpad> {
        assert!(slingshot.admin == tx_context::sender(ctx), EOperateNotAuth);
        // slingshot_event::sales_borrow_event<Item, Launchpad>(object::id(slingshot), tx_context::sender(ctx));
        object_table::borrow(&slingshot.sales, sales_id)
    }


    public fun borrow_admin<Item: key+store, Launchpad: store>(slingshot: &Slingshot<Item, Launchpad>): address {
        slingshot.admin
    }

    public fun borrow_live<Item: key+store, Launchpad: store>(slingshot: &Slingshot<Item, Launchpad>): bool {
        slingshot.live
    }

    public fun borrow_market_fee<Item: key+store, Launchpad: store>(slingshot: &Slingshot<Item, Launchpad>, ): u64 {
        slingshot.market_fee
    }

    public fun update_admin<Item: key+store, Launchpad: store>(
        slingshot: &mut Slingshot<Item, Launchpad>,
        admin: address,
        ctx: &mut TxContext
    ) {
        assert!(slingshot.admin == tx_context::sender(ctx), EOperateNotAuth);
        // slingshot_event::admin_update_event<Item, Launchpad>(object::id(slingshot), admin);
        slingshot.admin = admin
    }

    public fun modify_status<Item: key+store, Launchpad: store>(
        slingshot: &mut Slingshot<Item, Launchpad>,
        status: bool,
        ctx: &mut TxContext
    ) {
        assert!(slingshot.admin == tx_context::sender(ctx), EOperateNotAuth);
        // slingshot_event::live_change_event<Item, Launchpad>(object::id(slingshot), status);
        slingshot.live = status
    }
}


