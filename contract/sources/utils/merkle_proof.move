// Copyright 2019-2022 SwiftNFT Systems
// SPDX-License-Identifier: Apache-2.0
module swift_nft::merkle_proof {
    use std::vector;
    use std::hash;


    const ETwoVectorLengthMismatch: u64 = 0;

    public fun verify(proof: vector<vector<u8>>, root: vector<u8>, leaf: vector<u8>): bool {
        process_proof(proof, leaf) == root
    }


    fun process_proof(proof: vector<vector<u8>>, leaf: vector<u8>): vector<u8> {
        let computedHash = leaf;
        let i = 0;
        let length_proof = vector::length(&proof);
        while (i != length_proof) {
            computedHash = hash_hair(computedHash, *vector::borrow(&proof, i));
            i = i + 1
        };
        computedHash
    }

    fun compare(a: vector<u8>, b: vector<u8>): bool {
        let length_a = vector::length(&a);
        let length_b = vector::length(&b);
        assert!(length_b == length_a, ETwoVectorLengthMismatch);
        let i = 0;
        while (i < length_a) {
            let tep_a = *vector::borrow(&a, i);
            let tep_b = *vector::borrow(&b, i);
            if (tep_b < tep_a) {
                return true
            }else if (tep_a < tep_b) {
                return false
            };
            i = i + 1
        };
        return true
    }


    fun hash_hair(a: vector<u8>, b: vector<u8>): vector<u8> {
        return if (compare(a, b)) {
            efficient_hash(a, b)
        }else {
            efficient_hash(b, a)
        }
    }

    fun efficient_hash(a: vector<u8>, b: vector<u8>): vector<u8> {
        vector::append(&mut a, b);
        hash::sha3_256(a)
    }
}
