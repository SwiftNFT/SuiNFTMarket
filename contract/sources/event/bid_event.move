// Copyright 2019-2022 SwiftNFT Systems
// SPDX-License-Identifier: Apache-2.0
module swift_market::bid_event {
    use sui::object::ID;
    use sui::event;

    struct NewBidEvent has copy, drop {
        bid_id: ID,
        item_id: ID,
        bidder: address,
        amount: u64,
    }

    struct ChangeBidPriceEvent has copy, drop {
        bid_id: ID,
        item_id: ID,
        bidder: address,
        amount: u64,
    }

    struct BidCompleteEvent has copy, drop {
        bid_id: ID,
        item_id: ID,
        seller: address,
        amount: u64,
    }

    struct BidCancelEvent has copy, drop {
        bid_id: ID,
        item_id: ID,
        bidder: address,
    }


    public fun new_bid_event(bid_id: ID, item_id: ID, bidder: address, amount: u64) {
        event::emit(NewBidEvent {
            bid_id,
            item_id,
            bidder,
            amount
        })
    }

    public fun change_bid_price_event(bid_id: ID, item_id: ID, bidder: address, amount: u64) {
        event::emit(ChangeBidPriceEvent {
            bid_id,
            item_id,
            bidder,
            amount
        })
    }

    public fun bid_complete_event(item_id: ID, bid_id: ID, seller: address, amount: u64,
    ) {
        event::emit(BidCompleteEvent {
            bid_id,
            item_id,
            seller,
            amount
        })
    }

    public fun bid_cancel_event(item_id: ID, bid_id: ID, bidder: address) {
        event::emit(BidCancelEvent {
            bid_id,
            item_id,
            bidder
        })
    }
}
