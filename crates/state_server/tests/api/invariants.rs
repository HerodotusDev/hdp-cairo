use axum::Router;
use pathfinder_crypto::Felt;
use state_server::{create_router, AppState};

use crate::helpers::{get_state_proofs, read_actions, read_from_trie, write_to_trie};

async fn setup() -> anyhow::Result<Router> {
    Ok(create_router(AppState::new(":memory:")?))
}

#[tokio::test]
async fn isolation_root_stability_other_trie_unchanged() {
    let app = setup().await.unwrap();
    let (trie_a, trie_b) = (Felt::from(0xA_u64), Felt::from(0xB_u64));

    // Initial roots are zero (implicit)
    let root_a_0 = Felt::ZERO;
    let root_b_0 = Felt::ZERO;

    // Write to trie A
    let k1 = Felt::from(1u64);
    let v1 = Felt::from(100u64);
    let root_a_1 = write_to_trie(&app, trie_a, root_a_0, k1, v1).await.trie_root;

    assert_ne!(root_a_0, root_a_1, "Trie A root must change after write");
    // Trie B root should remain zero; reading from B yields zero
    assert_eq!(root_b_0, Felt::ZERO);
    let resp = get_state_proofs(&app, read_actions(trie_b, root_b_0, vec![k1])).await;
    assert_eq!(resp.state_proofs.len(), 1);
    // value must be zero in other trie
    if let types::proofs::injected_state::StateProof::Read(p) = &resp.state_proofs[0] {
        assert_eq!(p.leaf.data.value, Felt::ZERO);
    } else {
        panic!("expected read proof");
    }
}

#[tokio::test]
async fn deletion_semantics_write_zero() {
    let app = setup().await.unwrap();
    let label = Felt::from(0xC_u64);
    let (k, v) = (Felt::from(1u64), Felt::from(100u64));

    let r1 = write_to_trie(&app, label, Felt::ZERO, k, v).await.trie_root;
    let r2 = write_to_trie(&app, label, r1, k, Felt::ZERO).await.trie_root;

    // Implementation-specific: we assert value reads as zero post-deletion.
    // Assert a root change occurred (if deletion persists a state change) or document otherwise.
    assert_ne!(r1, r2, "Deleting a key should change the root");
    // Assert that read returns zero.
    let resp = get_state_proofs(&app, read_actions(label, r2, vec![k])).await;
    if let types::proofs::injected_state::StateProof::Read(p) = &resp.state_proofs[0] {
        assert_eq!(p.leaf.data.value, Felt::ZERO);
    } else {
        panic!("expected read proof");
    }
}

#[tokio::test]
async fn noop_write_same_value_keeps_root() {
    let app = setup().await.unwrap();
    let label = Felt::from(0xD_u64);
    let (k, v) = (Felt::from(2u64), Felt::from(200u64));

    let r1 = write_to_trie(&app, label, Felt::ZERO, k, v).await.trie_root;
    let r2 = write_to_trie(&app, label, r1, k, v).await.trie_root;

    // Define desired invariant: same (key,value) should not change root.
    assert_eq!(r1, r2, "No-op write should keep root unchanged");
}

#[tokio::test]
async fn order_independence_two_keys_on_empty_trie() {
    let app = setup().await.unwrap();
    let label = Felt::from(0xE_u64);
    let (k1, v1) = (Felt::from(10u64), Felt::from(1000u64));
    let (k2, v2) = (Felt::from(11u64), Felt::from(2000u64));

    let r_a1 = write_to_trie(&app, label, Felt::ZERO, k1, v1).await.trie_root;
    let r_a2 = write_to_trie(&app, label, r_a1, k2, v2).await.trie_root;

    // Fresh trie for reversed order
    let app2 = setup().await.unwrap();
    let r_b1 = write_to_trie(&app2, label, Felt::ZERO, k2, v2).await.trie_root;
    let r_b2 = write_to_trie(&app2, label, r_b1, k1, v1).await.trie_root;

    assert_eq!(r_a2, r_b2, "Order of inserting two distinct keys should not affect final root");
}

#[tokio::test]
async fn edge_inputs_zero_and_max() {
    let app = setup().await.unwrap();
    let label_zero = Felt::ZERO;
    let key_zero = Felt::ZERO;
    let val_zero = Felt::ZERO;
    let r0 = write_to_trie(&app, label_zero, Felt::ZERO, key_zero, val_zero).await.trie_root;
    let resp0 = get_state_proofs(&app, read_actions(label_zero, r0, vec![key_zero])).await;
    if let types::proofs::injected_state::StateProof::Read(p) = &resp0.state_proofs[0] {
        assert_eq!(p.leaf.data.value, Felt::ZERO);
    }

    // Max felt constrained by path length (251 bits). Use a 31-byte value with top bit clear.
    let max = Felt::from_hex_str("0x03ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff").unwrap();
    let label = Felt::from(0xF_u64);
    let r1 = write_to_trie(&app, label, Felt::ZERO, max, max).await.trie_root;
    let resp1 = read_from_trie(&app, label, r1, max).await;
    assert_eq!(resp1.value, max);
}
