// Copyright 2019-2022 SwiftNFT Systems
// SPDX-License-Identifier: Apache-2.0
module swift_nft::merkle_proof {
    use std::vector;
    use sui::hash;


    const ETwoVectorLengthMismatch: u64 = 0;

    public entry fun verify(proof: vector<vector<u8>>, root: vector<u8>, leaf: vector<u8>): bool {
        assert!(process_proof(proof, leaf) == root, ETwoVectorLengthMismatch);
        true
    }


    fun process_proof(proof: vector<vector<u8>>, leaf: vector<u8>): vector<u8> {
        let computed_hash = leaf;
        let i = 0;
        let length_proof = vector::length(&proof);
        while (i < length_proof) {
            computed_hash = hash_hair(computed_hash, *vector::borrow(&proof, i));
            i = i + 1
        };
        computed_hash
    }

    public fun lt(a: &vector<u8>, b: &vector<u8>): bool {
        let i = 0;
        let len = vector::length(a);
        assert!(len == vector::length(b), ETwoVectorLengthMismatch);

        while (i < len) {
            let aa = *vector::borrow(a, i);
            let bb = *vector::borrow(b, i);
            if (aa < bb) return true;
            if (aa > bb) return false;
            i = i + 1;
        };
        false
    }


    fun hash_hair(a: vector<u8>, b: vector<u8>): vector<u8> {
        if (lt(&a, &b)) efficient_hash(a, b) else efficient_hash(b, a)
    }

    fun efficient_hash(a: vector<u8>, b: vector<u8>): vector<u8> {
        vector::append(&mut a, b);
        hash::keccak256(&a)
    }

    #[test]
    fun test_verify() {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"f99692a8fccf12eb2bf6399f23bf9379e38a98367a75e250d53eb727c1385624");
        let root = x"59d3298db60c8c3ea35d3de0f43e297df7f27d8c3ba02555bcd7a2eee106aace";
        let leaf = x"45db79b20469c3d6b3c40ea3e4e76603cca6981e7765382ffa4cb1336154efe5";
        assert!(verify(proof, root, leaf), 0);
    }

}
