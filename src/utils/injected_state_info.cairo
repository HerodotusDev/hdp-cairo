namespace ProofType {
    const INCLUSION = 0;
    const NON_INCLUSION = 1;
    const UPDATE = 2;
}

func fetch_injected_state_info(id: felt) -> (info: InjectedStateInfo) {
    if (id == 0) {
        return (info=InjectedStateInfo(id=0, proof_type=ProofType.INCLUSION));
    }

    if (id == 1) {
        return (info=InjectedStateInfo(id=1, proof_type=ProofType.NON_INCLUSION));
    }

    if (id == 2) {
        return (info=InjectedStateInfo(id=2, proof_type=ProofType.UPDATE));
    }

    assert 0 = 1;
    return (info=InjectedStateInfo(id=0, proof_type=0));
}