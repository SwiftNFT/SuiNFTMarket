// Copyright 2019-2022 SwiftNFT Systems
// SPDX-License-Identifier: Apache-2.0
module swift_market::bid {
    use sui::object::{Self, UID, ID};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext, sender};
    use sui::transfer;
    use sui::dynamic_object_field as dof;
    use swift_market::market::{Self, Marketplace};
    use swift_market::bid_event;
    use ob_allowlist::allowlist::Allowlist;
    use nft_protocol::royalty_strategy_bps::BpsRoyaltyStrategy;
    use sui::transfer_policy::TransferPolicy;
    use sui::kiosk::Kiosk;
    use ob_request::transfer_request;
    use nft_protocol::transfer_allowlist;
    use nft_protocol::royalty_strategy_bps;
    use ob_kiosk::ob_kiosk;
    use sui::balance;
    use sui::transfer::{public_transfer, share_object};
    use sui::pay;

    ///Bid Item Object
    struct Bid<phantom CoinType> has key,store {
        id: UID,
        item_id: ID,
        bidder: address,
        // Locked funds
        funds: Coin<CoinType>,
    }

    ///Record some important information of the market
    struct BidMarketplace has key {
        id: UID,
        ///marketplace fee collected by marketplace
        beneficiary: address,
        ///marketplace fee  of the marketplace
        fee: u64,
    }

    fun init(ctx: &mut TxContext){
        let ob_market = BidMarketplace {
            id: object::new(ctx),
            beneficiary: sender(ctx),
            fee: 0,
        };
        share_object(ob_market)
    }


    const EBidObjectMismatch: u64 = 0;
    const ECoinType: u64 = 1;
    const ETimeLocking: u64 = 2;
    const ETwoObjectMismatch: u64 = 3;
    const ENoAuth: u64 = 4;
    const EObjectNoExist: u64 = 5;
    const EMarketFee: u64 = 6;


    public entry fun modify_ob_market(bid_market: &mut BidMarketplace, beneficiary: address, fee: u64) {
        assert!(fee < 10000, EMarketFee);
        bid_market.fee = fee;
        bid_market.beneficiary = beneficiary
    }
    ///Place a bid on an NFT and lock in the bid funds for a period of time
    public entry fun new_bid<CoinType>(item_id: ID, funds: Coin<CoinType>, ctx: &mut TxContext) {
        let amount = coin::value(&funds);
        //create a bid object
        let bid = Bid {
            id: object::new(ctx),
            item_id,
            bidder: tx_context::sender(ctx),
            funds,
        };
        let bid_id = object::id(&bid);
        transfer::public_share_object(bid);
        bid_event::new_bid_event(bid_id, item_id, tx_context::sender(ctx), amount);
    }

    ///Place a bid on an NFT and lock in the bid funds for a period of time
    public entry fun add_bid_price<CoinType>(bid: &mut Bid<CoinType>,
                                             funds: Coin<CoinType>,
                                             ctx: &mut TxContext) {
        assert!(bid.bidder == sender(ctx), ENoAuth);
        pay::join(&mut bid.funds, funds);
        let new_amount = coin::value(&bid.funds);
        bid_event::change_bid_price_event(object::id(bid), bid.item_id, tx_context::sender(ctx), new_amount);
    }

    ///Place a bid on an NFT and lock in the bid funds for a period of time
    public entry fun reduce_bid_price<CoinType>(bid: &mut Bid<CoinType>,
                                             amount: u64,
                                             ctx: &mut TxContext) {
        let sender = sender(ctx);
        assert!(bid.bidder == sender, ENoAuth);
        pay::split_and_transfer(&mut bid.funds, amount, sender, ctx);
        let new_amount = coin::value(&bid.funds);
        bid_event::change_bid_price_event(object::id(bid), bid.item_id, sender, new_amount);
    }


    ///Make bids on NFTs listed in the market
    public entry fun accept_bid_from_market<Item: key+store, CoinType>(
        bid_market: &BidMarketplace,
        market: &mut Marketplace<CoinType>,
        item_id: ID,
        bid: &mut Bid<CoinType>,
        ctx: &mut  TxContext
    ) {
        //Remove NFT from the market
        let items = market::delist(market, item_id, ctx);
        accept_bid<Item, CoinType>(bid_market, items, bid, ctx)
    }

    // public entry fun accept_ob_bid_no_orderbook<Item: key+store, CoinType>(
    //     bid: &mut Bid<CoinType>,
    //     allow_list: &Allowlist,
    //     royalty_strategy: &mut BpsRoyaltyStrategy<Item>,
    //     transfer_policy: &mut TransferPolicy<Item>,
    //     seller_kiosk: &mut Kiosk,
    //     buyer_kiosk: &mut Kiosk,
    //     ctx: &mut  TxContext
    // ) {
    //     let bid_price = coin::value(&bid.funds);
    //     let market_fee = bid_price * 150 /10000;
    //     let market_coin = coin::split(&mut bid.funds, market_fee, ctx);
    //     public_transfer(market_coin, @beneficiary);
    //     let ob_transfer_request = ob_kiosk::transfer_delegated<Item>(seller_kiosk, buyer_kiosk, bid.item_id, &object::new(ctx), bid_price, ctx);
    //     let bid_offer = balance::split(coin::balance_mut(&mut bid.funds), bid_price);
    //     transfer_request::set_paid(&mut ob_transfer_request, bid_offer, sender(ctx));
    //     transfer_allowlist::confirm_transfer(allow_list, &mut ob_transfer_request);
    //     royalty_strategy_bps::confirm_transfer<Item, CoinType>(royalty_strategy, &mut ob_transfer_request);
    //     transfer_request::confirm<Item, CoinType>(ob_transfer_request, transfer_policy, ctx);
    // }

    ///Make bids on NFTs unlisted in the market
    public entry fun accept_bid<Item: key+store, CoinType>(
        bid_market: &BidMarketplace,
        items: Item,
        bid: &mut Bid<CoinType>,
        ctx: &mut TxContext
    ) {
        let items_id = object::id(&items);
        assert!(items_id == bid.item_id, EBidObjectMismatch);
        let bid_id = object::id(bid);

        let amount = coin::value(&bid.funds);

        bid_event::bid_complete_event(object::id(&items), bid_id, tx_context::sender(ctx), amount);

        transfer::public_transfer(items, bid.bidder);
        let market_fee = amount * bid_market.fee / 10000;
        let receiver_amount = amount - market_fee;
        pay::split_and_transfer(&mut bid.funds, market_fee, bid_market.beneficiary, ctx);
        pay::split_and_transfer(&mut bid.funds, receiver_amount, tx_context::sender(ctx) ,ctx);
        // let Bid{
        //     id,
        //     item_id:_,
        //     bidder:_,
        //     funds
        // } = bid;
        // coin::destroy_zero(funds);
        // object::delete(id)
    }

    ///If the transaction is not completed,cancel bid and withdraw funds
    public entry fun cancel_bid<CoinType>(
        bid: &mut Bid<CoinType>,
        ctx: &mut TxContext) {
        assert!(bid.bidder == tx_context::sender(ctx), ENoAuth);
        let bid_id = object::id(bid);
        bid_event::bid_cancel_event(bid.item_id, bid_id, tx_context::sender(ctx));
        let amount = coin::value(&bid.funds);
        pay::split_and_transfer(&mut bid.funds, amount, tx_context::sender(ctx) ,ctx);
        // let Bid{
        //     id,
        //     item_id:_,
        //     bidder:_,
        //     funds
        // } = bid;
        // coin::destroy_zero(funds);
        // object::delete(id);
    }
}