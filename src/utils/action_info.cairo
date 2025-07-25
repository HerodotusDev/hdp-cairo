namespace Action {
    const INCLUSION = 0;
    const UPDATE = 1;
}

func fetch_action_info(action: felt) -> (info: ActionInfo) {
    if (action == 0) {
        return (info=ActionInfo(id=0, action=Action.INCLUSION));
    }

    if (action == 1) {
        return (info=ActionInfo(id=1, action=Action.UPDATE));
    }
}