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

    friend swift_nft::launchpad;

    struct Activity<phantom Item, phantom Launchpad>has key, store {
        id: UID,
        root: vector<u8>,
    }

    const ENotAuthGetWhiteList: u64 = 0;
    const ECreditAlreadyClaimed: u64 = 1;

    public(friend) fun create_activity<Item: key+store, Launchpad: store>(
        sale_id: ID,
        root: vector<u8>,
        ctx: &mut TxContext
    ) {
        let activity = Activity<Item, Launchpad> {
            id: object::new(ctx),
            root,
        };
        launchpad_event::activity_created_event(object::id(&activity), sale_id, root);
        transfer::share_object(activity);
    }

    public(friend) fun modify_activity<Item: key+store, Launchpad: store>(
        activity: &mut Activity<Item, Launchpad>,
        root: vector<u8>,
    ) {
        activity.root = root;
    }


    public fun check_whitelist<Item: key+store, Market: store>(
        activity: &Activity<Item, Market>,
        proof: vector<vector<u8>>,
        ctx: &TxContext
    ): bool {
        let sender = address::to_bytes(sender(ctx));
        merkle_proof::verify(proof, activity.root, sender)
    }
}
