// Copyright 2019-2022 SwiftNFT Systems
// SPDX-License-Identifier: Apache-2.0
module swift_market::market_event {
    use sui::object::ID;
    use sui::event;
    use std::ascii::String;

    struct MarketCreatedEvent has copy, drop {
        market_id: ID,
        collection_list: ID,
        owner: address,
    }

    struct CollectionCreatedEvent has copy, drop {
        collection_id: ID,
        creator_address: address
    }

    struct ItemListedEvent has copy, drop {
        collection_id: ID,
        item_id: ID,
        listing_id: ID,
        operator: address,
        price: u64,
        nft_type: String,
        ft_type: String,
        is_new_collection: bool
    }

    struct ItemBuyEvent has copy, drop {
        collection_id: ID,
        item_id: ID,
        from: address,
        to: address,
        nft_type: String,
        ft_type: String,
        price: u64,
    }

    struct CollectionWithdrawalEvent has copy, drop {
        collection_id: ID,
        from: address,
        to: address,
        nft_type: String,
        ft_type: String,
        price: u64,
    }

    struct ItemDeListedEvent has copy, drop {
        collection_id: ID,
        item_id: ID,
        listing_id: ID,
        operator: address,
        nft_type: String,
        ft_type: String,
        price: u64,

    }

    struct ItemAdjustPriceEvent has copy, drop {
        collection_id: ID,
        item_id: ID,
        operator: address,
        nft_type: String,
        ft_type: String,
        price: u64,
    }

    public fun market_created_event(market_id: ID, collection_list: ID, owner: address) {
        event::emit(MarketCreatedEvent {
            market_id,
            collection_list,
            owner
        })
    }

    public fun item_list_event(collection_id: ID, item_id: ID, listing_id: ID, operator: address, price: u64, nft_type: String, ft_type: String, is_new_collection: bool) {
        event::emit(ItemListedEvent {
            collection_id,
            item_id,
            listing_id,
            operator,
            price,
            nft_type,
            ft_type,
            is_new_collection
        })
    }

    public fun item_buy_event(collection_id: ID, item_id: ID, from: address, to: address, nft_type: String, ft_type: String, price: u64) {
        event::emit(ItemBuyEvent {
            collection_id,
            item_id,
            from,
            to,
            nft_type,
            ft_type,
            price
        })
    }

    public fun collection_withdrawal(collection_id: ID, from: address, to: address, nft_type: String, ft_type: String, price: u64) {
        event::emit(CollectionWithdrawalEvent {
            collection_id,
            from,
            to,
            nft_type,
            ft_type,
            price
        })
    }

    public fun item_delisted_event(collection_id: ID, item_id: ID, listing_id: ID, operator: address, nft_type: String, ft_type: String, price: u64) {
        event::emit(ItemDeListedEvent {
            collection_id,
            item_id,
            listing_id,
            operator,
            nft_type,
            ft_type,
            price,
        })
    }

    public fun item_adjust_price_event(collection_id: ID, item_id: ID, operator: address, nft_type: String, ft_type: String, price: u64) {
        event::emit(ItemAdjustPriceEvent {
            collection_id,
            item_id,
            operator,
            nft_type,
            ft_type,
            price
        })
    }
}
