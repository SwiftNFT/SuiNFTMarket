// Copyright 2019-2022 SwiftNFT Systems
// SPDX-License-Identifier: Apache-2.0
module swift_nft::launchpad_whitelist {
    use sui::object::{UID, ID};
    use sui::tx_context::{TxContext, sender};
    use sui::object;
    use sui::transfer;
    use swift_nft::merkle_proof;
    use sui::address;
    use swift_nft::launchpad_event;
    use sui::url::Url;
    use sui::url;
    use sui::vec_map;
    use sui::transfer::public_share_object;
    use std::string::utf8;
    use std::hash;

    friend swift_nft::launchpad;
    friend swift_nft::launchpad_v2;

    struct Activity has key, store {
        id: UID,
        root: vector<u8>,
        url: Url
    }

    struct ActivityList has key, store{
        id: UID,
        whitelist: vec_map::VecMap<ID, ID>,
    }

    const ENotAuthGetWhiteList: u64 = 0;
    const ECreditAlreadyClaimed: u64 = 1;

    fun init(ctx: &mut TxContext){
        public_share_object(ActivityList{
            id: object::new(ctx),
            whitelist: vec_map::empty<ID,ID>()
        })
    }

    public(friend) fun create_activity(
        activity_list:&mut ActivityList,
        sale_id: ID,
        root: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let url = url::new_unsafe_from_bytes(url);
        let activity = Activity {
            id: object::new(ctx),
            root,
            url
        };
        vec_map::insert(&mut activity_list.whitelist, sale_id, object::id(&activity));
        launchpad_event::activity_created_event(object::id(&activity), sale_id, root, url);
        transfer::share_object(activity);
    }

    public(friend) fun modify_activity(
        activity: &mut Activity,
        root: vector<u8>,
        url: vector<u8>,
    ) {
        activity.root = root;
        activity.url = url::new_unsafe_from_bytes(url);
    }


    public entry fun check_whitelist(
        activity: &Activity,
        proof: vector<vector<u8>>,
        ctx: &TxContext
    ): bool {
        let sender = address::to_bytes(sender(ctx));
        let leaf = hash::sha3_256(sender);
        merkle_proof::verify(proof, activity.root, leaf)
    }
}
