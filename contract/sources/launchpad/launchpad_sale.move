// Copyright 2019-2022 SwiftNFT Systems
// SPDX-License-Identifier: Apache-2.0
module swift_nft::launchpad_sale {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{TxContext};
    use std::vector;
    use sui::object_table::{Self, ObjectTable};
    use swift_nft::random;

    friend swift_nft::launchpad;


    struct Sale<phantom Item: key+store, Launchpad: store>has key, store {
        id: UID,
        whitelist: bool,
        nfts: ObjectTable<ID, Item>,
        reg: SaleRegistry<Item>,
        launchpad: Launchpad,
    }

    struct SaleRegistry<phantom Item: key+store> has key, store {
        id: UID,
        born: u64,
        nft_index: vector<ID>,
    }

    public(friend) fun create_sale<Item: key+store, Launchpad: store>(
        whitelist: bool,
        launchpad: Launchpad,
        ctx: &mut TxContext
    ): Sale<Item, Launchpad> {
        let reg = SaleRegistry<Item>{
            id: object::new(ctx),
            born: 0,
            nft_index: vector::empty()
        };
        let new_sale = Sale<Item, Launchpad> {
            id: object::new(ctx),
            whitelist,
            reg,
            nfts: object_table::new<ID, Item>(ctx),
            launchpad
        };
        return new_sale
    }

    public(friend) fun list_multi_item<Item: key+store, Launchpad: store>(sales: &mut Sale<Item, Launchpad>, nfts: vector<Item>) {
        let length = vector::length(&nfts);
        let i = 0;
        let reg = &mut sales.reg;
        while (i < length) {
            let item = vector::pop_back(&mut nfts);
            let nft_id = object::id(&item);
            vector::push_back(&mut reg.nft_index, nft_id);
            object_table::add(&mut sales.nfts, nft_id, item);
            i = i + 1;
        };
        // sale_event::item_list_event<Item, Market>(sale_id, ids);
        vector::destroy_empty(nfts);
    }

    public(friend) fun withdraw<Item: key+store, Launchpad: store>(
        sales: &mut Sale<Item, Launchpad>,
        ctx: &mut TxContext
    ): Item {
        // let sale_id = object::id(sales);
        let index = random::rand_u64_range(0, vector::length(&sales.reg.nft_index), ctx);

        let reg = &mut sales.reg;
        let nft_index = &mut reg.nft_index;
        let nft_id = vector::swap_remove(nft_index, index);
        reg.born = reg.born + 1;
        let item = object_table::remove(&mut sales.nfts, nft_id);
        // sale_event::item_withdraw_event<Item, Market>(sale_id, nft_id);
        return item
    }

    public(friend) fun delist_item<Item: key+store, Launchpad: store>(
        sales: &mut Sale<Item, Launchpad>,
        nfts: vector<ID>
    ): vector<Item> {
        // let sale_id = object::id(sales);
        let length = vector::length(&nfts);
        let item_result = vector::empty<Item>();
        let i = 0;
        let reg = &mut sales.reg;
        while (i < length) {
            let item_id = vector::pop_back(&mut nfts);

            let item = object_table::remove(&mut sales.nfts, item_id);
            let (_, nft_index) = vector::index_of(&reg.nft_index, &item_id);
            let nft_id = vector::swap_remove(&mut reg.nft_index, nft_index);
            assert!(nft_id == item_id, 0);
            vector::push_back(&mut item_result, item);
            i = i + 1;
        };
        // sale_event::item_unlist_event<Item, Market>(sale_id, nfts);
        return item_result
    }

    public(friend) fun modify_whitelist_status<Item: key+store, Launchpad: store>(sales: &mut Sale<Item, Launchpad>, status: bool) {
        sales.whitelist = status;
        // sale_event::wl_status_change_event<Item, Launchpad>(object::id(sales), true)
    }

    public entry fun whitelist_status<Item: key+store, Launchpad: store>(sales: &Sale<Item, Launchpad>): bool {
        return sales.whitelist
    }

    public(friend) fun get_mut_market<Item: key+store, Launchpad: store>(sales: &mut Sale<Item, Launchpad>): &mut Launchpad {
        return &mut sales.launchpad
    }

    public(friend) fun get_mut_sale<Item: key+store, Launchpad: store>(sales: &mut Sale<Item, Launchpad>): (&mut Launchpad, &mut ObjectTable<ID, Item>,&mut SaleRegistry<Item>) {
        return (&mut sales.launchpad, &mut sales.nfts, &mut sales.reg)
    }

    public fun get_launchpad<Item: key+store, Launchpad: store>(sales: &Sale<Item, Launchpad>): &Launchpad {
        return &sales.launchpad
    }

    public fun get_nfts<Item: key+store, Launchpad: store>(sales: &Sale<Item, Launchpad>): &ObjectTable<ID, Item> {
        return &sales.nfts
    }

}
