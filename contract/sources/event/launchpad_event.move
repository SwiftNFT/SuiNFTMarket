// Copyright 2019-2022 SwiftNFT Systems
// SPDX-License-Identifier: Apache-2.0
module swift_nft::launchpad_event {
    use sui::object::ID;
    use sui::event;
    use sui::url::Url;
    use std::string::String;

    struct SlingshotCreatedEvent has copy, drop {
        slingshot_id: ID,
        admin: address,
        live: bool,
        market_fee: u64,
        sales: vector<ID>
    }

    struct SaleCreatedEvent has copy, drop {
        sale_id: ID,
        launchpad_id: ID,
        white_list: bool,
        start_time: u64,
        end_time: u64,
        price: u64,
    }

    struct SalesRemoveEvent has copy, drop {
        slingshot_id: ID,
        sale_ids: vector<ID>,
        operator: address
    }

    struct ActivityCreatedEvent has copy, drop {
        activity_id: ID,
        sale_id: ID,
        root: String,
        url: Url,
    }

    public fun slingshot_create_event(
        slingshot_id: ID,
        admin: address,
        live: bool,
        market_fee: u64,
        sales: vector<ID>
    ) {
        event::emit(SlingshotCreatedEvent {
            slingshot_id,
            admin,
            live,
            market_fee,
            sales
        })
    }

    public fun sale_create_event(sale_id: ID, launchpad_id: ID, white_list: bool,
                                 start_time: u64, end_time: u64, price: u64, ) {
        event::emit(SaleCreatedEvent {
            sale_id,
            launchpad_id,
            white_list,
            start_time,
            end_time,
            price,
        })
    }

    public fun sale_remove_event(slingshot_id: ID, sale_ids: vector<ID>, operator: address) {
        event::emit(SalesRemoveEvent {
            slingshot_id,
            sale_ids,
            operator
        })
    }

    public fun activity_created_event(activity_id: ID, sale_id: ID, root: String, url: Url) {
        event::emit(ActivityCreatedEvent {
            activity_id,
            sale_id,
            root,
            url
        })
    }
}