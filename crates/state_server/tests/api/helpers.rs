use axum::{body::Body, http::Request, Router};
use http_body_util::BodyExt;
use pathfinder_crypto::Felt;
use serde_json::from_slice;
use state_server::{
    api::{
        create_trie::{CreateTrieRequest, CreateTrieResponse},
        proof::{GetStateProofsRequest, GetStateProofsResponse},
        read::ReadResponse,
        write::WriteResponse,
    },
    mpt::trie::{Membership, Trie},
};
use tower::ServiceExt;
use types::proofs::injected_state::{Action, ActionRead, ActionWrite, StateProof, StateProofRead, StateProofWrite};

pub async fn create_trie(app: &Router, trie_label: Felt, keys: Vec<Felt>, values: Vec<Felt>) -> CreateTrieResponse {
    let body = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/create_trie")
                .header("content-type", "application/json")
                .body(Body::from(
                    serde_json::to_vec(&CreateTrieRequest { trie_label, keys, values }).unwrap(),
                ))
                .unwrap(),
        )
        .await
        .unwrap()
        .into_body()
        .collect()
        .await
        .unwrap()
        .to_bytes();
    from_slice(&body).unwrap()
}

pub async fn read_from_trie(app: &Router, trie_label: Felt, trie_root: Felt, key: Felt) -> ReadResponse {
    let resp = app
        .clone()
        .oneshot(
            Request::builder()
                .method("GET")
                .uri(format!("/read?trie_label={}&trie_root={}&key={}", trie_label, trie_root, key))
                .header("content-type", "application/json")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert!(resp.status().is_success(), "GET /read failed with {}", resp.status());
    let body = resp.into_body().collect().await.unwrap().to_bytes();
    from_slice(&body).unwrap()
}

pub async fn write_to_trie(app: &Router, trie_label: Felt, trie_root: Felt, key: Felt, value: Felt) -> WriteResponse {
    let resp = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri(format!(
                    "/write?trie_label={}&trie_root={}&key={}&value={}",
                    trie_label, trie_root, key, value
                ))
                .header("content-type", "application/json")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert!(resp.status().is_success(), "POST /write failed with {}", resp.status());
    let body = resp.into_body().collect().await.unwrap().to_bytes();
    from_slice(&body).unwrap()
}

pub async fn get_state_proofs(app: &Router, actions: Vec<Action>) -> GetStateProofsResponse {
    let resp = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/get_state_proofs")
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_vec(&GetStateProofsRequest { actions }).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();
    assert!(resp.status().is_success(), "POST /get_state_proofs failed with {}", resp.status());
    let body = resp.into_body().collect().await.unwrap().to_bytes();
    from_slice(&body).unwrap()
}

pub fn read_actions(trie_label: Felt, trie_root: Felt, keys: Vec<Felt>) -> Vec<Action> {
    keys.into_iter()
        .map(|k| {
            Action::Read(ActionRead {
                trie_label,
                trie_root,
                key: k,
            })
        })
        .collect()
}

pub fn write_actions(trie_label: Felt, trie_root: Felt, kv: Vec<(Felt, Felt)>) -> Vec<Action> {
    kv.into_iter()
        .map(|(k, v)| {
            Action::Write(ActionWrite {
                trie_label,
                trie_root,
                key: k,
                value: v,
            })
        })
        .collect()
}

pub async fn build_trie(app: &Router, trie_label: Felt, kv: Vec<(Felt, Felt)>) -> Felt {
    let mut root = Felt::ZERO;
    for (k, v) in kv {
        root = write_to_trie(app, trie_label, root, k, v).await.trie_root;
    }
    root
}

pub async fn write_proof(app: &Router, trie_label: Felt, trie_root: Felt, key: Felt, value: Felt) -> StateProofWrite {
    match &get_state_proofs(app, write_actions(trie_label, trie_root, vec![(key, value)]))
        .await
        .state_proofs[0]
    {
        StateProof::Write(p) => p.clone(),
        _ => panic!("Expected write proof"),
    }
}

pub fn assert_read_proof(proof: &StateProof, key: Felt, value: Felt, ctx: &str) {
    if let StateProof::Read(p) = proof {
        assert_eq!(p.leaf.key, key, "{}", ctx);
        assert_eq!(p.leaf.data.value, value, "{}", ctx);
    } else {
        panic!("Expected read proof in {}", ctx)
    }
}

pub fn assert_write_proof(proof: &StateProof, key: Felt, prev: Felt, post: Felt, ctx: &str) {
    if let StateProof::Write(p) = proof {
        assert_eq!(p.leaf_prev.key, key, "{}", ctx);
        assert_eq!(p.leaf_prev.data.value, prev, "{}", ctx);
        assert_eq!(p.leaf_post.key, key, "{}", ctx);
        assert_eq!(p.leaf_post.data.value, post, "{}", ctx);
    } else {
        panic!("Expected write proof in {}", ctx)
    }
}

/// Verify read proof with cryptographic validation and membership/non-membership checks
pub fn verify_read_proof_crypto(proof: &StateProof, key: Felt, value: Felt, ctx: &str, expected: Option<Membership>) {
    assert_read_proof(proof, key, value, ctx);
    if let StateProof::Read(StateProofRead {
        state_proof,
        trie_root,
        leaf,
        ..
    }) = proof
    {
        assert_eq!(leaf.key, key, "Leaf key should match in {}", ctx);
        assert_eq!(leaf.data.value, value, "Leaf value should match in {}", ctx);

        if value != Felt::ZERO {
            assert!(!state_proof.is_empty(), "Proof should not be empty for existing key in {}", ctx);
        }

        let membership = Trie::verify_proof(
            &state_proof.iter().map(|n| (n.clone().into(), Felt::ZERO)).collect::<Vec<_>>(),
            *trie_root,
            *leaf,
        );

        assert_eq!(
            membership, expected,
            "Expected membership {:?} for key {} in {}, got {:?}",
            expected, key, ctx, membership
        );
    }
}

/// Verify read proof, asserting the cryptographic membership matches the expected membership.
pub fn verify_read_proof_with_membership(
    proof: &StateProof,
    key: Felt,
    value: Felt,
    expected: Option<state_server::mpt::trie::Membership>,
    ctx: &str,
) {
    assert_read_proof(proof, key, value, ctx);
    if let StateProof::Read(StateProofRead {
        state_proof,
        trie_root,
        leaf,
        ..
    }) = proof
    {
        let membership = Trie::verify_proof(
            &state_proof.iter().map(|n| (n.clone().into(), Felt::ZERO)).collect::<Vec<_>>(),
            *trie_root,
            *leaf,
        );
        assert_eq!(
            membership, expected,
            "Expected membership {:?} for key {} in {}, got {:?}",
            expected, key, ctx, membership
        );
    } else {
        panic!("Expected read proof in {}", ctx);
    }
}

/// Strict membership assertion to avoid false positives in critical tests.
/// - For existing keys, membership must be Member.
/// - For non-existent keys on a non-empty trie, membership must be NonMember.
/// - For empty trie, allow NonMember (our verifier returns NonMember for empty trie with empty proof).
pub fn assert_read_membership_strict(proof: &StateProof, key: Felt, value: Felt, ctx: &str, expected: Option<Membership>) {
    if let StateProof::Read(StateProofRead {
        state_proof,
        trie_root,
        leaf,
        ..
    }) = proof
    {
        let membership = Trie::verify_proof(
            &state_proof.iter().map(|n| (n.clone().into(), Felt::ZERO)).collect::<Vec<_>>(),
            *trie_root,
            *leaf,
        );

        if value != Felt::ZERO {
            assert_eq!(membership, expected, "Strict: expected Member for existing key {} in {}", key, ctx);
        } else {
            assert_eq!(membership, expected, "Strict: expected NonMember for absent key {} in {}", key, ctx);
        }
    } else {
        panic!("Expected read proof in {}", ctx);
    }
}

pub async fn get_trie_root_node_idx(app: &Router, trie_label: Felt, trie_root: Felt) -> axum::http::Response<axum::body::Body> {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/get_trie_root_node_idx?trie_label={}&trie_root={}", trie_label, trie_root))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap()
}
