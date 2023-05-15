// Copyright 2019-2022 SwiftNFT Systems
// SPDX-License-Identifier: Apache-2.0
module swift_nft::launchpad_event {
    use sui::object::ID;
    use sui::event;

    struct SlingshotCreatedEvent<phantom Item, phantom Launchpad> has copy, drop {
        slingshot_id: ID,
        collection_id: ID,
        admin: address,
        live: bool,
        market_fee: u64,
        sales: vector<ID>
    }

    struct SaleCreatedEvent<phantom Item, phantom Launchpad> has copy, drop {
        sale_id: ID,
        reg: ID,
        white_list: bool,
    }

    struct LaunchpadCreatedEvent<phantom Item, phantom Launchpad> has copy, drop {
        launchpad_id: ID,
        start_time: u64,
        end_time: u64,
        max_count: u64,
        allow_count: u64,
        price: u64,
        operator: address
    }

    struct SalesRemoveEvent<phantom Item, phantom Launchpad> has copy, drop {
        slingshot_id: ID,
        sale_ids: vector<ID>,
        operator: address
    }

    struct ActivityCreatedEvent<phantom Item, phantom Launchpad>has copy, drop {
        activity_id: ID,
        sale_id: ID,
        root: vector<u8>,
    }

    public fun launchpad_created_event<Item, Launchpad>(launchpad_id: ID, start_time: u64, end_time: u64, max_count: u64, allow_count: u64, price: u64, operator: address) {
        event::emit(LaunchpadCreatedEvent<Item, Launchpad> {
            launchpad_id,
            start_time,
            end_time,
            max_count,
            allow_count,
            price,
            operator
        })
    }

    public fun slingshot_create_event<Item, Launchpad>(slingshot_id: ID, collection_id: ID, admin: address, live: bool, market_fee: u64, sales: vector<ID>) {
        event::emit(SlingshotCreatedEvent<Item, Launchpad> {
            slingshot_id,
            collection_id,
            admin,
            live,
            market_fee,
            sales
        })
    }
    public fun sale_create_event<Item, Launchpad>(sale_id: ID, reg: ID, white_list: bool) {
        event::emit(SaleCreatedEvent<Item, Launchpad> {
            sale_id,
            reg,
            white_list
        })
    }

    public fun sale_remove_event<Item, Launchpad>(slingshot_id: ID, sale_ids: vector<ID>, operator: address) {
        event::emit(SalesRemoveEvent<Item, Launchpad> {
            slingshot_id,
            sale_ids,
            operator
        })
    }

    public fun activity_created_event<Item, Launchpad>(activity_id: ID, sale_id: ID, root: vector<u8>) {
        event::emit(ActivityCreatedEvent<Item, Launchpad> {
            activity_id,
            sale_id,
            root
        })
    }




}