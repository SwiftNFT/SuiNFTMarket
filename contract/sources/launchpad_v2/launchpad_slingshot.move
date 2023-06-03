// Copyright 2019-2022 SwiftNFT Systems
// SPDX-License-Identifier: Apache-2.0
module swift_market::launchpad_v2_slingshot {

    use sui::object::{Self, UID, ID};
    use sui::tx_context::TxContext;
    use sui::transfer;
    use std::vector;
    use sui::tx_context;
    use sui::dynamic_object_field as dof;

    struct Slingshot has key, store {
        id: UID,
        admin: address,
        live: bool,
        market_fee: u64,
    }

    const EOperateNotAuth: u64 = 0;



    public fun create_slingshot<Launchpad: key+ store>(
        admin: address,
        live: bool,
        market_fee: u64,
        launchpad: vector<Launchpad>,
        ctx: &mut TxContext
    ): ID {
        let slingshot = Slingshot{
            id: object::new(ctx),
            admin,
            live,
            market_fee,
        };
        let length = vector::length(&launchpad);
        let i = 0;
        while (i < length) {
            let pop_launchpad = vector::pop_back(&mut launchpad);
            let launchpad_id = object::id(&pop_launchpad);
            dof::add(&mut slingshot.id, launchpad_id, pop_launchpad);
            i = i + 1
        };
        vector::destroy_empty(launchpad);
        let slingshot_id = object::id(&slingshot);
        transfer::share_object(slingshot);

        return slingshot_id
    }

    public fun add_multi_launchpad<Launchpad: key+store>(
        slingshot: &mut Slingshot,
        launchpads: vector<Launchpad>,
        ctx: &mut TxContext
    ) {
        assert!(slingshot.admin == tx_context::sender(ctx), EOperateNotAuth);
        let length = vector::length(&launchpads);
        let launchpad_vec = vector::empty<ID>();

        let i = 0;
        while (i < length) {
            let pop_launchpad = vector::pop_back(&mut launchpads);
            let launchpad_id = object::id(&pop_launchpad);
            vector::push_back(&mut launchpad_vec, launchpad_id);
            dof::add(&mut slingshot.id, launchpad_id, pop_launchpad);
            i = i + 1
        };
        // launchpad_event::sales_add_event<Item, Launchpad>(object::id(slingshot), sale_vec);
        vector::destroy_empty(launchpads);
    }

    public fun remove_launchpad<Launchpad: key+store>(
        slingshot: &mut Slingshot,
        launchpad_id: ID
    ): Launchpad {
        dof::remove(&mut slingshot.id, launchpad_id)
    }

    public fun borrow_mut_launchpad<Launchpad: key+store>(
        slingshot: &mut Slingshot,
        launchpad_id: ID,
    ): &mut Launchpad {
        dof::borrow_mut(&mut slingshot.id, launchpad_id)
    }

    public fun borrow_launchpad<Launchpad: key+store>(
        slingshot: &Slingshot,
        launchpad_id: ID,
        ctx: &mut TxContext
    ): &Launchpad {
        assert!(slingshot.admin == tx_context::sender(ctx), EOperateNotAuth);
        dof::borrow(&slingshot.id, launchpad_id)
    }


    public fun borrow_admin(slingshot: &Slingshot): address {
        slingshot.admin
    }
    public fun borrow_live(slingshot: &Slingshot): bool {
        slingshot.live
    }
    public fun borrow_market_fee(slingshot: &Slingshot): u64 {
        slingshot.market_fee
    }
    public fun update_admin(
        slingshot: &mut Slingshot,
        admin: address,
        ctx: &mut TxContext
    ) {
        assert!(slingshot.admin == tx_context::sender(ctx), EOperateNotAuth);
        slingshot.admin = admin
    }

    public fun modify_status(
        slingshot: &mut Slingshot,
        status: bool,
        ctx: &mut TxContext
    ) {
        assert!(slingshot.admin == tx_context::sender(ctx), EOperateNotAuth);
        slingshot.live = status
    }
}


